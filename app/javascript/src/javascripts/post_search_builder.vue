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

    <div v-for="piece in activeFields" :key="piece.key" class="post-search-field builder-piece">
      <label :for="`search_${piece.key}`">{{ piece.name }}</label>
      <div class="post-search-field-controls">
        <select v-if="piece.type === 'select'" :id="`search_${piece.key}`" :name="`search[${piece.metatag}][]`" v-model="piece.value">
          <option value=""></option>
          <option v-for="opt in piece.options" :key="opt[1]" :value="opt[1]">{{ opt[0] }}</option>
        </select>
        <select v-else-if="piece.type === 'boolean'" :id="`search_${piece.key}`" :name="`search[${piece.metatag}][]`" v-model="piece.value">
          <option value="">Any</option>
          <option value="true">Yes</option>
          <option value="false">No</option>
        </select>
        <template v-else-if="piece.type === 'range'">
          <input v-if="piece.rangeOp === 'range'" type="text" v-model="piece.rangeMin" class="post-search-range-min" placeholder="min">
          <select v-model="piece.rangeOp" class="post-search-range-op">
            <option value="eq">=</option>
            <option value="gt">&gt;</option>
            <option value="gte">&gt;=</option>
            <option value="lt">&lt;</option>
            <option value="lte">&lt;=</option>
            <option value="range">..</option>
          </select>
          <input type="text" :id="`search_${piece.key}`" v-model="piece.rangeValue" :placeholder="piece.rangeOp === 'range' ? 'max' : ''">
          <input type="hidden" :name="`search[${piece.metatag}][]`" :value="buildFieldValue(piece)">
        </template>
        <input v-else type="text" :id="`search_${piece.key}`" :name="`search[${piece.metatag}][]`" v-model="piece.value"
               :data-autocomplete="autocompleteFor(piece.metatag)" :spellcheck="false">
        <select v-if="piece.negatable" :name="`search[${piece.metatag}_mode][]`" v-model="piece.mode" class="post-search-field-mode">
          <option value="must">Must</option>
          <option value="must_not">Must Not</option>
          <option value="should">Optional</option>
        </select>
        <button type="button" class="builder-remove-piece" title="Remove" @click="removeField(piece.key)">&times;</button>
      </div>
      <div v-if="piece.hint" class="hint">{{ piece.hint }}</div>
    </div>

    <div class="post-search-add-piece">
      <select v-model="pickerValue">
        <option value="">+ Add a search option...</option>
        <option value="__character_group__">Character Group</option>
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

  let nextKey = 0;

  export default {
    props: {
      fields: { type: Array, required: true },
      initialGeneralTags: { type: String, default: "" },
      initialGroups: { type: Array, default: () => [] },
      initialValues: { type: Object, default: () => ({}) },
      initialModes: { type: Object, default: () => ({}) },
    },
    data() {
      // A field's initial value/mode is a plain scalar for a single occurrence, or an array
      // once the same metatag showed up more than once in the search being edited (see
      // PostSearch::FormParser) - either way, one piece per value.
      const activeFields = [];
      Object.keys(this.initialValues).forEach((metatag) => {
        const values = Array.isArray(this.initialValues[metatag]) ? this.initialValues[metatag] : [this.initialValues[metatag]];
        const modes = Array.isArray(this.initialModes[metatag]) ? this.initialModes[metatag] : [this.initialModes[metatag]];
        values.forEach((value, i) => activeFields.push(this.toPiece(metatag, value, modes[i])));
      });
      return {
        generalTags: this.initialGeneralTags,
        characterGroups: this.initialGroups.map((g) => ({ key: nextKey++, tags: g.tags || "", mode: g.mode || "must" })),
        activeFields,
        pickerValue: "",
      };
    },
    computed: {
      // Mirrors PostSearch::QueryBuilder#build (same token order: general tags, then
      // character groups, then fields) so this always shows exactly what submitting the
      // form will actually search for.
      previewTags() {
        const tokens = this.generalTags.trim().split(/\s+/).filter(Boolean);

        this.characterGroups.forEach((group) => {
          const names = group.tags.trim().split(/\s+/).filter(Boolean);
          if (!names.length)
            return;
          const prefix = group.mode === "must_not" ? "-" : "";
          tokens.push(`${prefix}{${names.join(" ")}}`);
        });

        this.activeFields.forEach((field) => {
          const value = this.buildFieldValue(field);
          if (!value)
            return;
          if (field.type === "boolean") {
            tokens.push(`${field.metatag}:${value}`);
          } else {
            const prefix = field.negatable ? ({ must_not: "-", should: "~" }[field.mode] || "") : "";
            const quoted = value.includes(" ") ? `"${value}"` : value;
            tokens.push(`${prefix}${field.metatag}:${quoted}`);
          }
        });

        return tokens.join(" ");
      },
      // Every field stays pickable even once added - many metatags can be given more than
      // once (e.g. "locked:rating locked:status" requires both), so adding a field a second
      // time just adds another piece for it instead of being blocked.
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
      toPiece(metatag, value, mode) {
        const definition = this.fields.find((f) => f.metatag === metatag) || {};
        const piece = { ...definition, key: nextKey++, value: value || "", mode: mode || "must" };
        if (definition.type === "range")
          Object.assign(piece, this.parseRangeValue(value || ""));
        return piece;
      },
      // Same operator syntax as ParseValue.range (see app/logical/post_search/fields.rb) -
      // splits a raw metatag value like ">100" or "50..100" into the pieces the operator
      // selector/inputs need, for pre-filling a range field from an existing search.
      parseRangeValue(raw) {
        const empty = { rangeOp: "eq", rangeMin: "", rangeValue: "" };
        if (!raw)
          return empty;
        if (raw.startsWith("<="))
          return { rangeOp: "lte", rangeMin: "", rangeValue: raw.slice(2) };
        if (raw.startsWith("<"))
          return { rangeOp: "lt", rangeMin: "", rangeValue: raw.slice(1) };
        if (raw.startsWith(">="))
          return { rangeOp: "gte", rangeMin: "", rangeValue: raw.slice(2) };
        if (raw.startsWith(">"))
          return { rangeOp: "gt", rangeMin: "", rangeValue: raw.slice(1) };
        // Covers "min..max", and also the bare "min.." / "..max" forms (an empty side just
        // round-trips as an empty box, rather than being silently rewritten into >=/<= -
        // both mean the same thing server-side, but editing shouldn't change what you typed.
        if (raw.includes("..")) {
          const [min, max] = raw.split("..");
          return { rangeOp: "range", rangeMin: min, rangeValue: max };
        }
        return { rangeOp: "eq", rangeMin: "", rangeValue: raw };
      },
      // The reverse of parseRangeValue - also doubles as the plain-field case (just the
      // trimmed value), since both feed into the same tags-string token construction.
      buildFieldValue(piece) {
        if (piece.type !== "range")
          return (piece.value || "").trim();

        const min = (piece.rangeMin || "").trim();
        const value = (piece.rangeValue || "").trim();
        if (piece.rangeOp === "range") {
          return min || value ? `${min}..${value}` : "";
        }
        if (!value)
          return "";
        const prefixes = { gt: ">", gte: ">=", lt: "<", lte: "<=", eq: "" };
        return `${prefixes[piece.rangeOp] || ""}${value}`;
      },
      addPiece() {
        if (this.pickerValue === "__character_group__") {
          this.characterGroups.push({ key: nextKey++, tags: "", mode: "must" });
        } else if (this.pickerValue) {
          this.activeFields.push(this.toPiece(this.pickerValue, "", "must"));
        }
        this.pickerValue = "";
        nextTick(() => this.initAutocomplete());
      },
      removeField(key) {
        this.activeFields = this.activeFields.filter((f) => f.key !== key);
      },
      removeGroup(index) {
        this.characterGroups.splice(index, 1);
      },
      autocompleteFor(metatag) {
        if (["user", "approver", "disapprover", "commenter", "noter", "noteupdater", "favoritedby", "upvote", "downvote", "voted", "flagger", "deletedby"].includes(metatag))
          return "user";
        if (metatag === "pool")
          return "pool";
        return null;
      },
      initAutocomplete() {
        if (Autocomplete.initialize_tag_autocomplete)
          Autocomplete.initialize_tag_autocomplete();
      },
    },
  };
</script>
