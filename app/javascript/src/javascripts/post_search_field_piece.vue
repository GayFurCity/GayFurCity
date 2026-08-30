<template>
  <div class="post-search-field builder-piece">
    <label :for="`search_${piece.key}`">{{ piece.name }}</label>
    <div class="post-search-field-controls">
      <select v-if="piece.type === 'select'" :id="`search_${piece.key}`" v-model="piece.value">
        <option value=""></option>
        <option v-for="opt in piece.options" :key="opt[1]" :value="opt[1]">{{ opt[0] }}</option>
      </select>
      <select v-else-if="piece.type === 'boolean'" :id="`search_${piece.key}`" v-model="piece.value">
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
      </template>
      <input v-else type="text" :id="`search_${piece.key}`" v-model="piece.value"
             :data-autocomplete="autocompleteFor(piece.metatag)" :spellcheck="false">
      <select v-if="piece.negatable" v-model="piece.mode" class="post-search-field-mode">
        <option value="must">Must</option>
        <option value="must_not">Must Not</option>
        <option value="should">Optional</option>
      </select>
      <button type="button" class="builder-remove-piece" title="Remove" @click="$emit('remove')">&times;</button>
    </div>
    <div v-if="piece.hint" class="hint">{{ piece.hint }}</div>
  </div>
</template>

<script>
  import { autocompleteFor } from "./post_search_field_utils";

  export default {
    props: {
      piece: { type: Object, required: true },
    },
    emits: ["remove"],
    methods: {
      autocompleteFor,
    },
  };
</script>
