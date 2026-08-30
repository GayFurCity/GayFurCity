<template>
  <div class="post-search-builder">
    <div class="post-search-preview">
      <label>Search Preview</label>
      <code>{{ previewTags || "(empty search)" }}</code>
    </div>

    <div class="post-search-field builder-fixed-field">
      <label for="search_general_tags">General Tags</label>
      <div class="post-search-field-controls">
        <textarea id="search_general_tags" name="search[general_tags]" v-model="generalTags" rows="3"
                  data-autocomplete="tag-query" :spellcheck="false"></textarea>
      </div>
    </div>

    <div v-for="(group, gIndex) in characterGroups" :key="group.key" class="character-group-card builder-piece">
      <div class="character-group-card-fields">
        <label :for="`search_character_group_${gIndex}`">Character Group - tags that must all be on the same character</label>
        <textarea :id="`search_character_group_${gIndex}`" v-model="group.tags" rows="2" class="tag-textarea"
                  :name="`search[character_groups][${gIndex}][tags][]`" placeholder="e.g. fluffy_(oc) blue_eyes"
                  data-autocomplete="tag-query" :spellcheck="false"></textarea>
        <select :name="`search[character_groups][${gIndex}][mode]`" v-model="group.mode">
          <option value="must">Must</option>
          <option value="must_not">Must Not</option>
        </select>
      </div>
      <button type="button" class="builder-remove-piece" title="Remove" @click="removeGroup(gIndex)">&times;</button>
    </div>

    <div v-for="(group, gIndex) in boolGroups" :key="group.key" class="character-group-card bool-group-card builder-piece">
      <div class="bool-group-card-row">
        <div class="character-group-card-fields">
          <label :for="`search_bool_group_${gIndex}`">Tag Group - tags combined as a single AND/OR/NOT unit</label>
          <textarea :id="`search_bool_group_${gIndex}`" v-model="group.tags" rows="2" class="tag-textarea"
                    placeholder="e.g. solo duo" data-autocomplete="tag-query" :spellcheck="false"></textarea>
          <select :name="`search[bool_groups][${gIndex}][mode]`" v-model="group.mode">
            <option value="must">Must</option>
            <option value="must_not">Must Not</option>
            <option value="should">Optional</option>
          </select>
          <!-- The submitted value - group.tags plus a rendered token per metatag piece below,
               composed client-side the same way previewTags composes the overall search. -->
          <input type="hidden" :name="`search[bool_groups][${gIndex}][tags][]`" :value="composedBoolGroupTags(group)">
        </div>
        <button type="button" class="builder-remove-piece" title="Remove" @click="removeBoolGroup(gIndex)">&times;</button>
      </div>

      <div v-if="group.fields.length" class="bool-group-fields">
        <PostSearchFieldPiece v-for="piece in group.fields" :key="piece.key" :piece="piece"
                              @remove="removeGroupField(group, piece.key)" />
      </div>

      <div class="post-search-add-piece bool-group-add-piece">
        <select v-model="group.pickerValue">
          <option value="">+ Add a metatag...</option>
          <optgroup v-for="cat in categoriesWithFields" :key="cat" :label="cat">
            <option v-for="f in fieldsByCategory[cat]" :key="f.metatag" :value="f.metatag">{{ f.name }}</option>
          </optgroup>
        </select>
        <button type="button" :disabled="!group.pickerValue" @click="addGroupField(group)">Add</button>
      </div>
    </div>

    <template v-for="piece in activeFields" :key="piece.key">
      <PostSearchFieldPiece :piece="piece" @remove="removeField(piece.key)" />
      <input type="hidden" :name="`search[${piece.metatag}][]`" :value="buildFieldValue(piece)">
      <input v-if="piece.negatable" type="hidden" :name="`search[${piece.metatag}_mode][]`" :value="piece.mode">
    </template>

    <div class="post-search-add-piece">
      <select v-model="pickerValue">
        <option value="">+ Add a search option...</option>
        <option value="__character_group__">Character Group</option>
        <option value="__bool_group__">Tag Group</option>
        <optgroup v-for="cat in categoriesWithFields" :key="cat" :label="cat">
          <option v-for="f in fieldsByCategory[cat]" :key="f.metatag" :value="f.metatag">{{ f.name }}</option>
        </optgroup>
      </select>
      <button type="button" :disabled="!pickerValue" @click="addPiece">Add</button>
    </div>
  </div>
</template>

<script>
  import Autocomplete from "./autocomplete.js.erb";
  import { nextTick } from "vue";
  import PostSearchFieldPiece from "./post_search_field_piece.vue";
  import { genKey, toPiece, piecesFromValues, buildFieldValue, fieldToken } from "./post_search_field_utils";

  export default {
    components: { PostSearchFieldPiece },
    props: {
      fields: { type: Array, required: true },
      initialGeneralTags: { type: String, default: "" },
      initialGroups: { type: Array, default: () => [] },
      initialBoolGroups: { type: Array, default: () => [] },
      initialValues: { type: Object, default: () => ({}) },
      initialModes: { type: Object, default: () => ({}) },
    },
    data() {
      return {
        generalTags: this.initialGeneralTags,
        characterGroups: this.initialGroups.map((g) => ({ key: genKey(), tags: g.tags || "", mode: g.mode || "must" })),
        // A group's saved tags text isn't re-parsed back apart on its own - PostSearch::
        // FormParser already splits any metatag it recognizes out of a group's text into that
        // group's own field_values/field_modes (the same way it does for the top-level
        // search), so its plain remainder is what round-trips into group.tags here.
        boolGroups: this.initialBoolGroups.map((g) => ({
          key: genKey(),
          tags: g.tags || "",
          mode: g.mode || "must",
          fields: piecesFromValues(this.fields, g.field_values, g.field_modes),
          pickerValue: "",
        })),
        activeFields: piecesFromValues(this.fields, this.initialValues, this.initialModes),
        pickerValue: "",
      };
    },
    computed: {
      // Mirrors PostSearch::QueryBuilder#build (same token order: general tags, then
      // character groups, then () tag groups, then fields) so this always shows exactly what
      // submitting the form will actually search for.
      previewTags() {
        const tokens = this.generalTags.trim().split(/\s+/).filter(Boolean);

        this.characterGroups.forEach((group) => {
          const names = group.tags.trim().split(/\s+/).filter(Boolean);
          if (!names.length)
            return;
          const prefix = group.mode === "must_not" ? "-" : "";
          tokens.push(`${prefix}{${names.join(" ")}}`);
        });

        this.boolGroups.forEach((group) => {
          const tags = this.composedBoolGroupTags(group);
          if (!tags)
            return;
          const prefix = { must_not: "-", should: "~" }[group.mode] || "";
          tokens.push(`${prefix}(${tags})`);
        });

        this.activeFields.forEach((field) => {
          const token = fieldToken(field);
          if (token)
            tokens.push(token);
        });

        return tokens.join(" ");
      },
      // Every field stays pickable even once added - many metatags can be given more than
      // once (e.g. "locked:rating locked:status" requires both), so adding a field a second
      // time just adds another piece for it instead of being blocked. Shared by the top-level
      // picker and every () tag group's own nested picker.
      fieldsByCategory() {
        const byCategory = {};
        this.fields.forEach((f) => {
          (byCategory[f.category] ||= []).push(f);
        });
        return byCategory;
      },
      categoriesWithFields() {
        return Object.keys(this.fieldsByCategory).filter((cat) => this.fieldsByCategory[cat].length);
      },
    },
    mounted() {
      this.initAutocomplete();
    },
    methods: {
      buildFieldValue,
      // A () group's own submitted text: its free-typed tags plus a rendered token for each
      // metatag piece added to it. group.tags is kept as one raw chunk rather than
      // split/rejoined - it can itself contain a nested () group or a quoted metatag value,
      // either of which whitespace-splitting would tear apart.
      composedBoolGroupTags(group) {
        const parts = [];
        const rawTags = group.tags.trim();
        if (rawTags)
          parts.push(rawTags);
        group.fields.forEach((piece) => {
          const token = fieldToken(piece);
          if (token)
            parts.push(token);
        });
        return parts.join(" ");
      },
      addPiece() {
        if (this.pickerValue === "__character_group__") {
          this.characterGroups.push({ key: genKey(), tags: "", mode: "must" });
        } else if (this.pickerValue === "__bool_group__") {
          this.boolGroups.push({ key: genKey(), tags: "", mode: "must", fields: [], pickerValue: "" });
        } else if (this.pickerValue) {
          this.activeFields.push(toPiece(this.fields, this.pickerValue, "", "must"));
        }
        this.pickerValue = "";
        nextTick(() => this.initAutocomplete());
      },
      addGroupField(group) {
        if (!group.pickerValue)
          return;
        group.fields.push(toPiece(this.fields, group.pickerValue, "", "must"));
        group.pickerValue = "";
        nextTick(() => this.initAutocomplete());
      },
      removeField(key) {
        this.activeFields = this.activeFields.filter((f) => f.key !== key);
      },
      removeGroupField(group, key) {
        group.fields = group.fields.filter((f) => f.key !== key);
      },
      removeGroup(index) {
        this.characterGroups.splice(index, 1);
      },
      removeBoolGroup(index) {
        this.boolGroups.splice(index, 1);
      },
      initAutocomplete() {
        if (Autocomplete.initialize_tag_autocomplete)
          Autocomplete.initialize_tag_autocomplete();
      },
    },
  };
</script>
