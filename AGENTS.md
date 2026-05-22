# BarrelsExpanded Agent Guide

Esta guia define como trabajar en este repositorio sin romper las decisiones de arquitectura que ya sostienen el mod.

## Objetivo del mod

BarrelsExpanded convierte barriles del mundo de Project Zomboid Build 42 en objetos interactivos con contenido persistente, sincronizado y usable en SP/MP. El servidor debe seguir siendo la fuente de verdad para cualquier cambio real de estado.

## Principios de trabajo

- Lee primero el codigo existente y sigue sus patrones locales.
- Mantene cambios chicos, enfocados y faciles de revisar.
- Preferi nombres explicitos antes que abstracciones nuevas.
- No mezcles refactors generales con cambios funcionales.
- No agregues dependencias ni frameworks externos salvo que haya una necesidad clara.
- Preserva compatibilidad con Project Zomboid Build 42.
- Trata cambios locales no propios como trabajo del usuario: no los reviertas.

## Arquitectura

El codigo esta dividido por responsabilidad:

- `client/`: UI, acciones temporizadas, comandos salientes y sincronizacion visual.
- `client/actions/`: timed actions agrupadas por dominio; deben heredar de `BarrEx_BarrelActionBase.lua` para armar payloads de red consistentes.
- `client/context/`: construccion del menu contextual, textos, tooltips, disponibilidad y acciones del menu.
- `server/`: validacion autoritativa, mutaciones reales, locks, snapshots, resolucion de objetos y comandos entrantes.
- `shared/`: modelos, reglas puras, adaptadores, constantes, configuracion y utilidades compartidas.
- `shared/core/`: reglas de interaccion y transferencia que pueden usarse desde cliente y servidor.
- `shared/config/`: configuracion por dominio; evita volver a concentrar todo en `BarrEx_Constant.lua`.

Este archivo es la guia viva de arquitectura para agentes. Si una decision nueva cambia estos criterios, actualiza esta guia en el mismo cambio.

## Server autoritativo

- El cliente puede mostrar opciones, iniciar timed actions y pedir operaciones.
- El cliente envia intenciones y aplica snapshots aceptados; no confirma exito por polling ni escribe estado real de barriles desde UI/actions.
- El servidor valida otra vez todo lo importante antes de mutar estado.
- La mutacion real de barriles debe entrar por servicios del servidor, especialmente `BarrEx_BarrelActionService.lua` para acciones cortas y `BarrEx_TransferService.lua` para transferencias y vaciados progresivos.
- No confies en datos enviados por el cliente para cantidades, items, distancias, herramientas o estado del barril.
- Usa `BarrEx_BarrelLockService.lua` para cualquier accion que pueda competir por el mismo barril.
- Despues de cambios persistentes, incrementa `revision`, persiste con `BarrEx_BarrelData.lua`, transmite modData y responde con snapshot via `BarrEx_BarrelActionNotifier.lua` o `BarrEx_TransferNotifier.lua`.

## Persistencia y modData

- No escribas datos persistentes del barril a mano desde multiples lugares.
- Usa `BarrEx_BarrelData.lua` como puerta principal para leer, normalizar y escribir estado de barriles.
- Mantene `modData` serializable con tablas Lua normales. No guardes funciones, objetos vivos, arrays especiales ni referencias temporales.
- Los datos persistentes deben poder sobrevivir guardados, reinicios y multiplayer.
- Si agregas campos nuevos, conserva compatibilidad con barriles ya guardados.
- `revision` es parte del estado persistente y del snapshot; solo debe incrementarse cuando cambia el estado persistente del barril.

## Separacion de responsabilidades

- `BarrEx_LiquidContainerAdapter.lua` debe aislar diferencias de APIs de liquidos/items del juego.
- `BarrEx_TransferRules.lua` debe contener calculos puros de transferencia, sin efectos secundarios.
- `BarrEx_InteractionRules.lua` debe validar herramientas, rango e items compartidos por cliente/servidor.
- `BarrEx_ContextMenuAvailability.lua` decide si una opcion se muestra habilitada.
- `BarrEx_ContextMenuActions.lua` conecta opciones del menu con acciones concretas.
- `BarrEx_ContextMenuText.lua` concentra textos y etiquetas de UI.
- `BarrEx_ContextMenuTooltips.lua` concentra tooltips e iconos.
- `BarrEx_BarrelActionBase.lua` concentra payload base, `actionId`, identidad de barril y revision cliente.
- `BarrEx_BarrelStateService.lua` concentra snapshots autoritativos y respuestas `requestBarrelState`.
- `BarrEx_BarrelActionService.lua` concentra mutaciones cortas: abrir, beber y lavar; el vaciado progresivo usa `BarrEx_TransferService.lua`.
- `BarrEx_LiquidEndpointResolver.lua` concentra endpoints liquidos de mundo como barriles y generadores; futuros vehiculos o repostadores/surtidores deben entrar como nuevos adapters ahi antes de tocar el lifecycle general.
- Evita que archivos de UI muten estado real del mundo.

## Optimizacion para PZ/Kahlua

Project Zomboid usa Kahlua; las llamadas Lua -> Java y ciertos iteradores son costosos.

- Cachea getters usados varias veces dentro de una funcion: `player:getInventory()`, `barrel:getModData()`, `inventory:getItems()`, `items:size()`.
- En rutas calientes, cachea globals usados repetidamente: `math.max`, `math.min`, `string.format`, `tonumber`, etc.
- Evita trabajo pesado en `Events.OnTick`. Valida lo caro al inicio de la accion y deja el tick lo mas chico posible.
- Reduce llamadas Java dentro de loops. Guarda resultados como `item:getFullType()`, `LiquidAdapter.getLiquidType(item)` o `barrelData:getFreeCapacity()` si se reutilizan.
- Preferi bucles numericos para listas:

```lua
for i = 1, #items do
    local item = items[i]
end
```

- Evita `ipairs` en rutas sensibles. En UI ocasional no es critico, pero para codigo nuevo usa bucles numericos por defecto.
- Usa `pairs` solo para tablas que realmente son mapas/diccionarios.
- Considera `table.newarray()` solo para listas temporales puramente locales. No lo uses en `modData`, comandos de red ni datos que deban serializarse.
- No sacrifiques arquitectura por micro-optimizaciones fuera de rutas calientes.

## Tipado LuaLS

- Usa anotaciones EmmyLua/LuaLS en funciones nuevas o modificadas, especialmente en modulos compartidos, server-side y acciones temporizadas.
- Anota funciones publicas y helpers locales no triviales con `---@param` y `---@return`; no dejes contratos importantes como tablas anonimas si el analizador puede ayudarte.
- Cuando una tabla cruza capas, comandos de red, snapshots, endpoints o estados activos, define `---@class` o `---@alias` cerca del modulo que la produce.
- Prefere tipos concretos del juego cuando existan (`IsoPlayer`, `IsoObject`, `IsoGridSquare`, `IsoGenerator`, `InventoryItem`) y usa `any` solo en bordes defensivos con Java/Kahlua.
- Si una funcion devuelve `nil, reason`, documenta ambos retornos para que el caller tenga visible el contrato de error.
- Mantene las anotaciones sincronizadas con la logica real; un tipo demasiado amplio oculta bugs y uno falso genera ruido.

## Context menus y UX

- El menu contextual debe ser liviano: construir opciones, tooltips y acciones, no cambiar estado real.
- La disponibilidad en cliente es una ayuda de UX, no seguridad.
- Cuando agregues opciones nuevas, contempla estados deshabilitados y tooltips de razon.
- Reutiliza textos via traducciones/configuracion en vez de strings sueltos.
- Si agregas textos, actualiza EN y ES cuando corresponda.

### Pauta visual para menus y tooltips

- Prioriza una experiencia parecida a vanilla: labels cortos, opciones estables y tooltips para explicar condiciones.
- No repitas razones de bloqueo en cada label. La opcion debe conservar su nombre normal y la razon debe vivir en el tooltip.
- Usa `Text.withDisabledReason(...)` solo si no hay otra forma clara de mostrar el bloqueo; por defecto preferi label limpio + tooltip.
- Si una accion completa no se puede ejecutar por una sola razon global, deshabilita la opcion padre y no muestres un submenu lleno de opciones bloqueadas.
- Agrega el sufijo ` >` solo cuando la opcion realmente abre un submenu util con acciones disponibles.
- Para estados no disponibles usa `Tooltips.attachUnavailableTooltip(...)`, `Tooltips.attachActionUnavailableTooltip(...)` o `TooltipBuilder:unavailable(...)`; esos mensajes usan `Tooltips.COLORS.BAD`.
- No agregues headers genericos como `Status:`/`Estado:` para una unica razon de bloqueo; mostra la razon directa en el tooltip.
- Para alertas o advertencias que no bloquean necesariamente la accion, como beber agua contaminada, usa `Tooltips.COLORS.WARN`.
- Si la misma condicion bloquea una opcion concreta, como lavar vendas con agua contaminada, tratala como no disponible y usa `Tooltips.COLORS.BAD`.
- Para requisitos encontrados usa `Tooltips.COLORS.GOOD`; para requisitos faltantes o incompatibles usa `Tooltips.COLORS.BAD`.
- Para datos informativos, cantidades, liquidos, capacidades y nombres de contenedores usa colores neutros (`TEXT`, `MUTED`, `HEADER`).
- Los tooltips complejos deben armarse en `BarrEx_ContextMenuTooltips.lua` con `Tooltips.newBuilder()`; no concatenes colores o `<LINE>` desde `BarrEx_ContextMenu.lua`.
- La UI puede ocultar o deshabilitar opciones para mantener limpieza visual, pero el servidor debe seguir validando la accion completa.

## Multiplayer y red

- Los comandos de cliente deben llevar identificadores suficientes, pero el servidor debe resolver objetos/items por su cuenta.
- No mandes objetos vivos por red; manda IDs, tipos, coordenadas o payloads simples.
- Los payloads deben ser chicos, serializables y tolerantes a campos faltantes.
- Toda accion iniciada por red debe validar jugador, rango, herramienta, item, estado del barril y compatibilidad de liquido.
- Toda accion iniciada por cliente debe recibir `accepted/rejected` con `actionId`, `reason`, `barrelId`, `revision` y `snapshot` cuando el objeto pudo resolverse.
- El servidor no debe confiar en `objectIndex`; usalo solo como hint junto con `barrelId`, coords, sprite y resolucion cercana.
- No hagas broadcast global despues de cada accion: usa `transmitModData()`/sync de objeto para jugadores con chunk cargado y `requestBarrelState` para refresh bajo demanda.
- Mantene notificaciones de red separadas en capas como `BarrEx_TransferNotifier.lua`.

## Lifecycle de transferencias MP

- `start` de transferencia debe exigir `transferId`, barril resoluble, item resoluble, herramienta/rango validos y lock largo adquirido.
- El vaciado progresivo usa el mismo lifecycle largo con `mode="empty"` y `transferId`, pero no requiere item resoluble.
- Las transferencias largas (`pour`, `extract`, `empty`) avanzan por progreso cliente monotonicamente reportado: `update` solo registra `pendingClientProgress` y no muta mundo.
- El servidor aplica deltas desde `appliedProgress` hacia `pendingClientProgress`, calculando cantidad desde `totalAmount`; el cliente nunca manda cantidades.
- `complete` debe elevar `pendingClientProgress` a `1`, aplicar el remanente validado y cerrar la transferencia; no debe quedar drenaje/llenado post-animacion.
- Las transferencias endpoint-backed (`barrel_to_barrel`, `barrel_to_generator` y futuros modos para vehiculos/repostadores) deben reutilizar el mismo lifecycle largo y validar combinacion de endpoints, rango, herramienta cuando corresponda y locks antes de mutar.
- Los endpoints no barril no escriben `BarrEx_BarrelData`; deben sincronizarse con la API vanilla correspondiente, por ejemplo `generator:sync()` despues de cambiar combustible.
- El contexto activo puede cachear `barrel`, `barrelData`, `item`, `liquidType`, `barrelId` e `itemId`, pero antes de cada mutacion debe revalidar lock, identidad y rango; si el cache falla, usa resolucion estricta.
- `update`, `stop` y `complete` deben poder enviarse aunque el item ya no este resoluble en el inventario cliente; deben conservar `transferId`, `mode`, `barrelId`, `itemId` y el ultimo payload base conocido.
- En `mode="empty"`, `update`, `stop` y `complete` deben conservar `transferId`, `mode`, `barrelId` y el ultimo payload base conocido.
- La API publica de `BarrEx_TransferService.stop` y `BarrEx_TransferService.complete` nunca debe operar sin `transferId` explicito. Los cierres internos deben usar helpers internos como `stopActiveForPlayer(...)`.
- Los comandos tardios de `stop`/`complete` deben responder desde cache cerrada exacta por `playerKey + transferId`, sin mutar estado ni tomar locks nuevos.
- Los cierres de transferencia deben guardar datos suficientes para responder paquetes tardios: `transferId`, `mode`, `barrelId`, `itemId`, snapshot, `closedReason`, `closedRejected` y si ya fue notificado.
- Si un rechazo ya fue notificado y llega otro comando tardio para la misma transferencia cerrada, responde con snapshot/ack tecnico y evita duplicar mensajes visibles usando `silent=true`.
- Un payload final de transferencia con `completed=true` debe enviar `progress=1`; usa `movedAmount`, `totalAmount` y `closedReason` para explicar cierres parciales o cancelados.
- No uses caches cerradas como persistencia. Son temporales y solo existen para absorber orden de paquetes, timeouts y comandos tardios en MP.

## Configuracion

- No expandas `BarrEx_Constant.lua` como cajon general si existe un modulo de config mas adecuado.
- `BarrEx_Constant.lua` puede seguir funcionando como fachada de compatibilidad, pero los valores por dominio deben vivir en modulos especificos cuando el area crezca.
- Liquidos, herramientas, tiempos de transferencia y UI deben permanecer separados por dominio.
- Hoy ya existen configs especializadas para:
  - `config/BarrEx_LiquidConfig.lua`: tipos de liquido, contenedores compatibles y pesos por unidad.
  - `config/BarrEx_ToolConfig.lua`: herramientas requeridas para abrir, verter y extraer.
  - `config/BarrEx_TransferConfig.lua`: tiempos, intervalos de tick y sincronizacion de transferencias.
  - `config/BarrEx_ContextConfig.lua`: claves de contexto, UI y tooltips.
- Evita valores magicos en servicios; centralizalos si tienen significado de dominio.

## Roadmap de configuracion

Cuando el mod escale, extrae configuracion restante de `BarrEx_Constant.lua` hacia modulos chicos y nombrados por dominio. No implementes esta separacion por reflejo: hacelo cuando reduzca complejidad real o cuando el area empiece a cambiar seguido.

- `config/BarrEx_BarrelConfig.lua`: capacidad por defecto, peso vacio y futuros defaults fisicos del barril.
- `config/BarrEx_TileConfig.lua`: categorias de tiles, mapeo sprite -> categoria y distribuciones por tipo de tile.
- `config/BarrEx_SpawnConfig.lua`: perfiles de spawn, intervalos de reconciliacion y futuras reglas de peso/probabilidad.

Beneficios esperados de esa separacion:

- Cada modulo documenta un dominio concreto.
- Agregar nuevos sprites o perfiles no obliga a tocar logica central.
- Las reglas son mas faciles de revisar, probar y exponer a personalizacion futura.
- `BarrEx_Constant.lua` queda como fachada estable en vez de crecer como archivo multiproposito.

Si se crean estas configs, actualiza consumidores gradualmente y conserva compatibilidad con imports existentes cuando sea razonable.

## Metodologias a evitar

- No mover logica autoritativa al cliente.
- No escribir `modData` desde UI o timed actions si el servidor debe decidir.
- No duplicar reglas entre cliente y servidor cuando pueden vivir en `shared/core`.
- No usar scans completos del mundo o inventario en cada tick si se puede resolver por evento o por accion.
- No introducir globals nuevos para compartir estado.
- No usar `ipairs` o `pairs` por comodidad en codigo que puede ejecutarse muchas veces.
- No crear helpers minusculos dentro de loops sensibles.
- No hacer fallback silencioso que oculte errores de sincronizacion o corrupcion de datos.
- No cambiar estructura persistente sin ruta de compatibilidad.
- No mezclar traducciones hardcodeadas con claves existentes salvo fallback deliberado.

## Checklist antes de terminar

- El servidor sigue validando la accion?
- La mutacion real ocurre en server?
- El estado persistente pasa por `BarrEx_BarrelData.lua`?
- El cambio funciona en SP y MP conceptualmente?
- Evitaste trabajo innecesario en `OnTick`?
- Cacheaste getters Java si se usan repetidamente?
- Las traducciones EN/ES siguen completas?
- El cambio queda dentro de la responsabilidad del modulo tocado?
- Hay algun dato nuevo que necesite compatibilidad con partidas existentes?
