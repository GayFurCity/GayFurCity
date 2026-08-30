<template>
  <div class="character-group-editor">
    <div v-for="(group, index) in groups" :key="group.key" class="character-group-card">
      <div class="character-group-card-fields">
        <label :for="fieldId(index, 'characters')">Character(s)</label>
        <input :id="fieldId(index, 'characters')"
               v-model="group.characters"
               type="text"
               class="tag-textarea"
               :name="nativeNames ? `${paramName}[character_groups_attributes][${index}][characters][]` : undefined"
               placeholder="e.g. fluffy_(oc) (leave blank for an unknown/anonymous character)"
               data-autocomplete="tag-edit"
               :spellcheck="false">

        <label :for="fieldId(index, 'tags')">Tags for this character</label>
        <textarea :id="fieldId(index, 'tags')"
                  v-model="group.tags"
                  rows="3"
                  class="tag-textarea"
                  :name="nativeNames ? `${paramName}[character_groups_attributes][${index}][tags][]` : undefined"
                  placeholder="tags that apply to this character only"
                  data-autocomplete="tag-edit"
                  :spellcheck="false"></textarea>
      </div>
      <button type="button" class="character-group-remove" title="Remove character" @click="removeGroup(index)">&times;</button>
    </div>

    <button type="button" class="character-group-add" @click="addGroup">+ Add Character</button>
    <!--
      Submitted even with zero cards, as one group with an empty tags array (which the
      server discards as blank) - so the server can tell "no characters" (UI, clears any
      existing groups) apart from "not touched" (API/manual, existing groups untouched).
    -->
    <input v-if="nativeNames && groups.length === 0" type="hidden" :name="`${paramName}[character_groups_attributes][0][tags][]`" value="">
    <p class="hint">Tag any characters/subjects in this post here, if there are any. Everything else goes in the general tag box below.</p>
  </div>
</template>

<script>
  import Autocomplete from "./autocomplete.js.erb";
  import { nextTick } from "vue";

  let nextKey = 0;

  export default {
    props: {
      paramName: { type: String, default: "post" },
      initialGroups: { type: Array, default: () => [] },
      nativeNames: { type: Boolean, default: true },
    },
    emits: ["update:modelValue"],
    data() {
      return {
        groups: this.initialGroups.map((g) => this.toRow(g)),
      };
    },
    watch: {
      groups: {
        deep: true,
        handler() {
          this.emitGroups();
        },
      },
    },
    mounted() {
      this.emitGroups();
      this.initAutocomplete();
    },
    methods: {
      toRow(g) {
        return { key: nextKey++, characters: (g.characters || []).join(" "), tags: (g.tags || []).join(" ") };
      },
      fieldId(index, field) {
        return `${this.paramName}_character_group_${index}_${field}`;
      },
      addGroup() {
        this.groups.push({ key: nextKey++, characters: "", tags: "" });
        nextTick(() => this.initAutocomplete());
      },
      removeGroup(index) {
        this.groups.splice(index, 1);
      },
      emitGroups() {
        this.$emit("update:modelValue", this.groups.map((g) => ({
          characters: g.characters.trim().split(/\s+/).filter(Boolean),
          tags: g.tags.trim().split(/\s+/).filter(Boolean),
        })));
      },
      initAutocomplete() {
        if (Autocomplete.initialize_tag_autocomplete)
          Autocomplete.initialize_tag_autocomplete();
      },
    },
  };
</script>
