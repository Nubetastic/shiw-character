# RSG Character creation, clothing and appearance scripts.

## Install
I suggest putting this into an [apperance] folder and ensure it right after [framework]

rsg-clothingstore
has a sql file, but server.lua will generate it on startup if it does not exist.

rsg-changing_room radial menu. This is not needed, there are preset locations for access as well.
```lua
{
    id = 'changing_room',
    title = 'Change',
    icon = 'door-closed',
    type = 'client',
    event = 'rsg-changing_room:client:open',
    shouldClose = true,
},
```


## Changes from fork
- Increased ui size, added scale slide bar that to all ui. syncs between ui's.
    - Each resource has its own Config.ScaleModifier to adjust the default scale size.|}
- Removed custom player model hash loading in favor of the streamed ped method.
    - works with db-femped and other types like it.
    - rsg-wardrobe still works with it.
- Clothing Store
    - removed item creation. All clothes are stored data.
    - Items arranged players head to toe instead of alphabetical
    - Added 0 item for each item slide bar so items can be removed.
    - Added outfits, can be saved with no outfit number cap.
    - Up down arrows moves between items, left right arrow slides item slide bar.
    - Merged blackwater and saintdenis store into one store.
        - Ran a spawn check on all items and commented out the ones that did not work.
        - All shops now use the same inventory.
    - replaced shop j button with ox_target zone so it fits with the current rsg-shop style.
        - its on the spot where the shop npc would stand.
            - This script does not spawn npcs.
- Barbershop
    - left right slides type, and up down slides color.
    - Added Style, works just like outfits so players can save different looks.
    - lowered prices
- ChangingRoom
    - new script that allows players to apply outfits and looks.
    - Can be done at location, several preconfigured ones, or with radial menu.
        - Radial menu needs a reopen delay so it does not stay open in the changingroom ui.
        - preconfig locations are all ox_target zones where store npcs are standing.
            - blips added to changing room locations for them, speak to npc to get in.