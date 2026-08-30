// Shared helpers for building/reading a search field "piece" (one metatag input plus its
// mode) - used both by the top-level field picker and by each () tag group's own nested
// picker in post_search_builder.vue, so a group can add/remove metatags the same way the
// top-level search can.

let nextKey = 0;

export function genKey () {
  return nextKey++;
}

export function toPiece (fields, metatag, value, mode) {
  const definition = fields.find((f) => f.metatag === metatag) || {};
  const piece = { ...definition, key: genKey(), value: value || "", mode: mode || "must" };
  if (definition.type === "range")
    Object.assign(piece, parseRangeValue(value || ""));
  return piece;
}

// Expands a values/modes pair (as returned by PostSearch::FormParser, for the top-level search
// or for one () group's own recognized metatags) into one piece per value - a value is a plain
// scalar for a single occurrence, or an array once the same metatag showed up more than once.
export function piecesFromValues (fields, values, modes) {
  const pieces = [];
  Object.keys(values || {}).forEach((metatag) => {
    const vals = Array.isArray(values[metatag]) ? values[metatag] : [values[metatag]];
    const mds = Array.isArray((modes || {})[metatag]) ? modes[metatag] : [(modes || {})[metatag]];
    vals.forEach((value, i) => pieces.push(toPiece(fields, metatag, value, mds[i])));
  });
  return pieces;
}

// Same operator syntax as ParseValue.range (see app/logical/post_search/fields.rb) - splits a
// raw metatag value like ">100" or "50..100" into the pieces the operator selector/inputs
// need, for pre-filling a range field from an existing search.
export function parseRangeValue (raw) {
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
  // round-trips as an empty box, rather than being silently rewritten into >=/<= - both mean
  // the same thing server-side, but editing shouldn't change what you typed.
  if (raw.includes("..")) {
    const [min, max] = raw.split("..");
    return { rangeOp: "range", rangeMin: min, rangeValue: max };
  }
  return { rangeOp: "eq", rangeMin: "", rangeValue: raw };
}

// The reverse of parseRangeValue - also doubles as the plain-field case (just the trimmed
// value), since both feed into the same tags-string token construction.
export function buildFieldValue (piece) {
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
}

// A field piece rendered as a "metatag:value" token, mode prefix included - what a piece
// contributes to a () group's composed inner text, or to the top-level preview.
export function fieldToken (piece) {
  const value = buildFieldValue(piece);
  if (!value)
    return "";
  if (piece.type === "boolean")
    return `${piece.metatag}:${value}`;

  const prefix = piece.negatable ? ({ must_not: "-", should: "~" }[piece.mode] || "") : "";
  const quoted = value.includes(" ") ? `"${value}"` : value;
  return `${prefix}${piece.metatag}:${quoted}`;
}

export function autocompleteFor (metatag) {
  if (["user", "approver", "disapprover", "commenter", "noter", "noteupdater", "favoritedby", "upvote", "downvote", "voted", "flagger", "deletedby"].includes(metatag))
    return "user";
  if (metatag === "pool")
    return "pool";
  return null;
}
