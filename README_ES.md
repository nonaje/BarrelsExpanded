# Barrels Expanded [MP + SP]

![Barrels Expanded](preview.png)

> Un mod para Project Zomboid Build 42 que convierte los barriles del mundo en recursos utiles de supervivencia con contenido aleatorio, estado persistente e interacciones jugables para singleplayer y multiplayer.

---

## Por que se creo?

El mundo de Project Zomboid esta lleno de barriles industriales y militares, pero la mayoria son solo escenografia. Puedes pasar al lado, construir alrededor o ignorarlos, pero casi nunca importan.

**Barrels Expanded** cambia eso. Los barriles pueden convertirse en agua de emergencia, reservas de gasolina, suministros de limpieza o contenedores vacios para usar en tu base. No sabes que hay dentro hasta abrir uno.

El objetivo es hacer que la exploracion sea mas interesante sin convertir el juego en otra cosa.

---

## Que hace?

El mod agrega comportamiento interactivo a barriles vanilla del mundo. Puedes:

- Abrir e inspeccionar barriles.
- Beber desde barriles con agua cuando el liquido es bebible.
- Lavarte, lavar ropa y lavar objetos compatibles usando agua del barril.
- Verter liquidos compatibles al barril.
- Llenar recipientes compatibles desde el barril.
- Vaciar barriles de forma progresiva cuando necesitas limpiarlos o cambiar su contenido.
- Levantar, mover y colocar barriles abiertos conservando su contenido y peso.

El contenido del barril se revela en la primera apertura:

- Tipo de liquido: Agua, Agua Contaminada, Gasolina, Lejia o Vacio.
- Cantidad: entre 1 y 160 unidades cuando hay liquido.

Una vez generado, el estado del barril queda guardado en el mundo y compartido en multiplayer.

---

## Funciones existentes

1. **Abrir barril** con una herramienta requerida: Palanca, Palanca Forjada, Destornillador, Llave de Tuberia o Tijeras de Chapa.
2. **Inspeccionar informacion del barril** desde el menu contextual Barril: tipo de liquido, nivel, requisitos, iconos de items y razones de deshabilitado.
3. **Beber del barril** cuando contiene Agua o Agua Contaminada.
4. **Lavar desde barril**:
   - Lavado del personaje.
   - Lavado de ropa y objetos lavables del inventario.
   - Limpieza de objetos tipo vendaje compatibles cuando el agua es segura.
   - El jabon es opcional, pero afecta la velocidad/comportamiento de limpieza.
5. **Verter al barril** desde recipientes compatibles del inventario, requiere Embudo.
6. **Llenar recipientes desde el barril** usando recipientes compatibles del inventario, requiere Manguera de Goma.
7. **Llenar todo / menu agrupado** con agrupacion de recipientes estilo vanilla.
8. **Vaciado progresivo** que drena liquido durante la accion temporizada; si se interrumpe, conserva la cantidad ya drenada.
9. **Contenido aleatorio en primera apertura** segun categoria del tile.
10. **Estado persistente del barril** que sobrevive guardados, recargas, levantar/colocar y reinicios del servidor.
11. **Comportamiento multiplayer seguro** con proteccion contra uso solapado del mismo barril.
12. **Peso dinamico del barril** segun tipo y cantidad de liquido.
13. **Soporte singleplayer y multiplayer**.
14. **Compatibilidad opcional con mods** para bidones militares de gasolina y agua de DamnLib/USMIL en transferencias de liquidos.
15. **Traducciones actuales**: Ingles, Espanol y Espanol Argentino.

### Datos de juego

| Categoria | Estado actual |
|---|---|
| Tipos de liquido | Agua, Agua Contaminada, Gasolina, Lejia, Vacio |
| Capacidad del barril | 160 unidades |
| Consumo por beber | 0.12 unidades por accion de beber |
| Costo por lavado | 1 unidad por segmento de cuerpo/item lavado |
| Tiles soportados | Barriles industriales, militares y crafteados |
| Herramientas de transferencia | Embudo para verter, Manguera de Goma para llenar recipientes |

---

## Funcionalidades planeadas

Estas son ideas para versiones futuras, no funciones actuales:

- **Logistica de gasolina**: recargar generadores o vehiculos desde barriles de gasolina.
- **Transferencia barril a barril**: organizar recursos entre barriles de una base.
- **Etiquetas o marcadores de propiedad**: mejor organizacion en bases multiplayer.
- **Opciones Sandbox**: ajustar rareza, capacidad, perfiles de aparicion, herramientas requeridas y comportamiento.
- **Sistema de condicion del barril**: oxido, dano, fugas, contaminacion o riesgos de confiabilidad.
- **Tratamiento de agua**: pasos de gameplay para volver mas segura el agua contaminada.

---

## Compatibilidad

- **Version del juego:** Project Zomboid Build 42
- **Multiplayer:** Soportado
- **Singleplayer:** Soportado
- **Solo servidor:** No soportado; el mod tambien debe estar activo en los clientes
- **Instalacion segura:** Pensado para funcionar con partidas existentes; siempre conviene hacer backup antes de agregar o quitar mods

---

## Traducciones

Traducciones actuales:

- Ingles
- Espanol
- Espanol Argentino

La ayuda de la comunidad con traducciones es bienvenida. Si quieres ayudar a traducir Barrels Expanded a otro idioma o mejorar una traduccion existente, los aportes y sugerencias son apreciados.

---

## Instalacion

1. Suscribete al mod en Steam Workshop.
2. Activalo desde el menu **Mods** en el menu principal o al crear partida.
3. No requiere configuracion adicional.

---

*[English](README.md)*
