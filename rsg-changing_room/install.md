# rsg-changing_room installation

Add the resource after its dependencies in `server.cfg`:

```cfg
ensure rsg-appearance
ensure rsg-clothingstore
ensure rsg-barbershop
ensure rsg-changing_room
```

Add this client item to your radial-menu configuration. The exact parent menu can be changed to suit your setup:

```lua
{
    id = 'changing_room',
    title = 'Change',
    icon = 'door-closed',
    type = 'client',
    event = 'rsg-changing_room:client:open',
    shouldClose = true,
}
```

The public integration event is:

```lua
TriggerEvent('rsg-changing_room:client:open')
```

For temporary testing, trigger `rsg-changing_room:client:open` from the client console or another resource.
