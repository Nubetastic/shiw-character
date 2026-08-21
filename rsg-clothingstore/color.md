# Clothing Color Options

## Short answer

Yes, clothing can use color controls similar to the saddle and horse-hair controls.

This feature should exist **only inside `rsg-clothingstore`**. Players will not receive these extra clothing color controls while creating their character. They will visit a clothing store afterward to select, color, and purchase clothing.

A clothing item can have as many as **three color sliders**:

- `tints[1]` - first material/color region
- `tints[2]` - second material/color region
- `tints[3]` - third material/color region

These are not RGB red, green, and blue values. Each value selects a color from the item's MetaPed tint palette. The garment decides which visible material or section each tint controls.

Not every clothing item will visibly use all three values. Depending on how Rockstar made the asset, an item may use one, two, three, or none of the tint channels. The sliders cannot create additional independently colored sections that are not present in the asset.

## What the current resources already support

`rsg-clothingstore` already normalizes and saves the following fields for each clothing item:

```lua
palette = 'tint_generic_clean',
tints = { 0, 0, 0 }
```

The store sends previews through:

```lua
TriggerEvent('rsg-clothing:client:equipClothing', previewItem, { skipResync = true })
```

`rsg-appearance` already accepts `palette` and all three `tints`, stores them in its clothing cache, and applies them with native `0x4EFC1F8FF1AD94DE`.

`rsg-appearance` is only the existing backend used to apply and restore the selected clothing color. No color UI needs to be added to the character creator or another appearance menu.

The clothing-store server also preserves all three values when saving purchased clothes, active clothes, and outfits. This means the basic data path already exists. Most of the work would be adding the NUI controls and making sure a changed color is represented correctly in ownership and purchase logic.

## Recommended right-panel layout

Keep the existing **Variant** slider at the top. Under it, show color sliders only for a tint-enabled item:

```text
Variant       4 / 10
[-------------]

Primary       12
[-------------]

Secondary     27
[-------------]

Detail         3
[-------------]
```

Recommended labels:

- **Primary** for `tints[1]`
- **Secondary** for `tints[2]`
- **Detail** for `tints[3]`

The store defaults to three sliders per item. An item can override that default when it uses fewer channels. For example:

```lua
colorChannels = 1
```

or:

```lua
colorChannels = 3
```

If `colorChannels` is `0`, do not show color sliders. Values `1`, `2`, or `3` control how many sliders that item displays. This allows useless controls to be disabled after checking the asset in RedM.

## Player flow

1. The player finishes creating their character normally.
2. The player visits an `rsg-clothingstore` location.
3. The player selects a clothing category and variant.
4. The right panel shows the configured color sliders for that item.
5. The player previews the colors directly on their character.
6. The player buys the clothing with the selected colors.
7. The selected colors are saved with their active clothes and saved outfits.

The character creator, `rsg-barbershop`, and other appearance interfaces should not display these clothing color controls.

## Item types and limitations

### Ped clothing

`Kaf = "Ped"` items are the clearest candidates. Their drawable, albedo, normal, material, palette, and three tint values are already represented in the store data. These should be tested first.

### Classic clothing

Most current shop entries are `Kaf = "Classic"` hash-based components. `rsg-appearance` contains a Classic tint path, but whether a particular component responds depends on the component and its tint material setup.

Do not automatically enable sliders for every Classic item. First test a small sample from each category in RedM. Some of the existing numbered variants may already be baked Rockstar color variants rather than one tintable base item.

### Palette choice

The palette controls the available color table and how it looks on a material. Examples already present in the resource include `METAPED_TINT_COMBINED_LEATHER` and `tint_generic_clean`.

For the first implementation, keep each item's configured palette fixed and expose only its tint channels. A palette selector can be added later, but it multiplies the combinations that must be visually checked and saved.

## Required implementation changes

### 1. NUI state and controls

In `html/index.html`:

- Add three tint values to the selected item state.
- Render one to three color sliders below the Variant slider according to `colorChannels`.
- On input, update the selected item's `tints` array.
- Post the updated item through the existing `previewItem` callback for live preview.
- Debounce or otherwise limit preview posts while dragging so rapid input does not queue many delayed clothing equips.

### 2. Preview behavior

In `client/client.lua`:

- Continue using `NormalizeClientItem` and `ApplyStorePreviewItem`.
- Clamp received tint indices to the tested palette range.
- Keep the current per-category preview token behavior so only the newest preview is applied.

The active preview event already passes `palette` and `tints` into `rsg-appearance`; a separate color native should not be added to the NUI callback unless live testing proves the canonical equip event cannot refresh a tint quickly enough.

### 3. Ownership and purchase identity

This needs an explicit decision before coding.

For `Ped` items, the current item key includes all three tint values. Changing a slider would therefore create a different key. That would make each color combination look like a separate purchasable item.

Recommended behavior:

- Ownership should be based on the clothing base item, not its selected tint values.
- Buying one item should allow the player to recolor that owned item without buying every color combination again.
- The selected `palette` and `tints` should still be stored on the active clothing and saved outfits.

This requires separating the stable ownership key from the customized appearance data. The server must also calculate and validate the price from the configured base item rather than trusting color-modified NUI data.

### 4. Saving

The existing normalization already retains:

```lua
palette = item.pal or item.palette or item._p
tints = { tint1, tint2, tint3 }
```

Once the customized item reaches the existing purchase/apply callbacks, active clothes and outfits should retain the selected colors. This still needs an in-game reconnect test because the final visual restore happens inside `rsg-appearance`.

## Suggested first pass

1. Select one known tintable `Ped` clothing item.
2. Configure it with `colorChannels = 3` and a fixed known palette.
3. Add the three right-panel sliders with a tested index range.
4. Confirm which sliders visibly affect that asset.
5. Reduce `colorChannels` if the asset uses fewer channels.
6. Buy it, close and reopen the store, change outfits, and reconnect.
7. Repeat with one Classic item before enabling Classic categories broadly.

## RedM validation checklist

- Each shown slider changes a visible region of the selected item.
- Moving one slider does not reset the other two.
- Rapid slider movement does not leave an older preview applied last.
- Switching variants loads that variant's current/default tint values.
- Switching categories preserves the selected color in the pending outfit.
- Purchase charges once for the base clothing item.
- An owned item remains owned after recoloring.
- Saved outfits retain independent colors for each clothing item.
- Colors restore after store close, outfit switching, relogging, and resource restart.
- Coat anti-clipping and conflicting categories still behave normally.

## Recommendation

Implement the feature only in the `rsg-clothingstore` right panel, after character creation. Use **up to three sliders per item**, controlled by item configuration. Start with known tintable `Ped` assets, keep the palette fixed per item, and verify Classic components individually. `rsg-appearance` should remain the backend that applies and restores the saved values; it does not need another player-facing color menu.
