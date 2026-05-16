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
- `client/context/`: construccion del menu contextual, textos, tooltips, disponibilidad y acciones del menu.
- `server/`: validacion autoritativa, mutaciones reales, locks, resolucion de objetos y comandos entrantes.
- `shared/`: modelos, reglas puras, adaptadores, constantes, configuracion y utilidades compartidas.
- `shared/core/`: reglas de interaccion y transferencia que pueden usarse desde cliente y servidor.
- `shared/config/`: configuracion por dominio; evita volver a concentrar todo en `BarrEx_Constant.lua`.

Este archivo es la guia viva de arquitectura para agentes. Si una decision nueva cambia estos criterios, actualiza esta guia en el mismo cambio.

## Server autoritativo

- El cliente puede mostrar opciones, iniciar timed actions y pedir operaciones.
- El servidor valida otra vez todo lo importante antes de mutar estado.
- La mutacion real de liquidos debe vivir en servicios del servidor, especialmente `BarrEx_TransferService.lua` y `BarrEx_BarrelUseService.lua`.
- No confies en datos enviados por el cliente para cantidades, items, distancias, herramientas o estado del barril.
- Usa locks de transferencia cuando una accion pueda competir por el mismo barril.
- Despues de cambios persistentes en barriles, sincroniza con `transmitModData()` cuando corresponda.

## Persistencia y modData

- No escribas datos persistentes del barril a mano desde multiples lugares.
- Usa `BarrEx_BarrelData.lua` como puerta principal para leer, normalizar y escribir estado de barriles.
- Mantene `modData` serializable con tablas Lua normales. No guardes funciones, objetos vivos, arrays especiales ni referencias temporales.
- Los datos persistentes deben poder sobrevivir guardados, reinicios y multiplayer.
- Si agregas campos nuevos, conserva compatibilidad con barriles ya guardados.

## Separacion de responsabilidades

- `BarrEx_LiquidContainerAdapter.lua` debe aislar diferencias de APIs de liquidos/items del juego.
- `BarrEx_TransferRules.lua` debe contener calculos puros de transferencia, sin efectos secundarios.
- `BarrEx_InteractionRules.lua` debe validar herramientas, rango e items compartidos por cliente/servidor.
- `BarrEx_ContextMenuAvailability.lua` decide si una opcion se muestra habilitada.
- `BarrEx_ContextMenuActions.lua` conecta opciones del menu con acciones concretas.
- `BarrEx_ContextMenuText.lua` concentra textos y etiquetas de UI.
- `BarrEx_ContextMenuTooltips.lua` concentra tooltips e iconos.
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

## Context menus y UX

- El menu contextual debe ser liviano: construir opciones, tooltips y acciones, no cambiar estado real.
- La disponibilidad en cliente es una ayuda de UX, no seguridad.
- Cuando agregues opciones nuevas, contempla estados deshabilitados y tooltips de razon.
- Reutiliza textos via traducciones/configuracion en vez de strings sueltos.
- Si agregas textos, actualiza EN y ES cuando corresponda.

## Multiplayer y red

- Los comandos de cliente deben llevar identificadores suficientes, pero el servidor debe resolver objetos/items por su cuenta.
- No mandes objetos vivos por red; manda IDs, tipos, coordenadas o payloads simples.
- Los payloads deben ser chicos, serializables y tolerantes a campos faltantes.
- Toda accion iniciada por red debe validar jugador, rango, herramienta, item, estado del barril y compatibilidad de liquido.
- Mantene notificaciones de red separadas en capas como `BarrEx_TransferNotifier.lua`.

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
