# CONTEXTO DEL PROYECTO: TRACKIO

## 1. DESCRIPCIÓN GENERAL

"Trackio" es una aplicación multiplataforma (Web, Android, iOS) desarrollada con Flutter y MapLibre GL orientada a la edición masiva y avanzada de archivos GPX de montaña. La aplicación almacena de forma persistente y reactiva las sesiones del usuario en una base de datos local (Isar Database) para evitar pérdidas de datos.

## 2. INTERFAZ Y COMPORTAMIENTO GRÁFICO (UX)

El mapa ocupa siempre el 100% del fondo de la pantalla. El resto de módulos flotan o se acoplan sobre él según la plataforma:

- **Distribución Web (Escritorio):**
  - Un panel lateral izquierdo permanente (25% de ancho) actúa como gestor de capas de tracks e incluye las herramientas de edición.
  - Un gráfico de elevaciones fijo en la zona inferior (75% restante de ancho).
  - Al pasar el ratón (`onmouseover`) por encima de otros tracks en el mapa, se muestra una unión efímera discontinua. Al hacer clic, se consolida la fusión.
- **Distribución Móvil (Android/iOS):**
  - Un sistema de paneles inferiores deslizantes (Bottom Sheets) para interactuar con la lista de tracks y herramientas sin saturar el mapa.
  - El gráfico de elevaciones se mantiene fijo en la zona inferior.
  - Para paliar la falta de precisión táctil del dedo, la app utiliza una **Retícula/Mira de precisión fija en el centro de la pantalla**, y el usuario arrastra el mapa por debajo de ella.

## 3. REGLAS DE NEGOCIO Y HERRAMIENTAS DE EDICIÓN

Cada track importado se trata como una capa individualizada (tipo Photoshop). El Gestor de Capas centraliza la lista con un Checkbox (visibilidad), un círculo de color (selector dinámico individual) y el nombre. Al seleccionar un track, se habilitan las herramientas globales:

- **Inversión de Track:** Invierte el sentido del trazo dando la vuelta al array de puntos.
- **Herramienta de Recorte (Split) con Retícula Central:**
  1. Mientras el mapa se mueve (`onCameraMove`), se calcula en tiempo real un efecto imán (_snapping_) al punto de track más cercano a la retícula, pintando un nodo magnético visual.
  2. Cuando el mapa se detiene por completo (`onCameraIdle`), aparece un botón flotante contextual cerca del centro ("Cortar aquí") que permite seleccionar de forma milimétrica el punto exacto y dividir el trazo en dos tracks independientes.
- **Herramienta de Unión (Merge) Interactiva:**
  - El usuario selecciona el primer track y activa "Unir".
  - En Móvil, mueve el mapa con la retícula hasta el inicio del segundo track. El extremo de la unión se imanta de forma magnética (_snapping_) al trazo. Al detenerse el mapa, un botón contextual consolida la fusión.
- **Perfil de Elevaciones y Selección de Tramos:**
  - El gráfico se sitúa en la parte inferior de la pantalla.
  - Permite seleccionar un tramo específico (arrastrando el dedo/ratón por el gráfico o mapa).
  - Una barra horitzontal translúcida flotante, ubicada justo encima del gráfico, muestra dinámicamente las estadísticas del tramo seleccionado: Distancia total, Desnivel positivo (+), Desnivel negativo (-) y tiempo.

## 4. REQUISITOS TÉCNICOS

- **Framework:** Flutter (Web compilado con CanvasKit para WebGL; Android/iOS).
- **Mapa:** MapLibre GL con optimización de datos transformando los GPX a estructuras nativas de Dart (`List<LatLng>`) o GeoJSON para manipulación asíncrona a 60 fps mediante actualizaciones de propiedades de capa (`paint`).
- **Base de datos:** Isar Database para la persistencia local de la sesión de edición.
- **Gestión de Estado:** Flutter Riverpod con controladores desacoplados de la UI.
