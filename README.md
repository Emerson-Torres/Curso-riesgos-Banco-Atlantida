# Claude IA como herramienta de trabajo · Curso de Riesgos · Banco Atlántida

Material interno de capacitación (5 módulos · 15 horas). **No debe publicarse en internet.**

## Estructura

```
├─ index.html                     redirige a la Bienvenida
├─ Bienvenida_Curso_Riesgos_Banco_Atlantida.html
├─ ModuloN_Titulo_del_Modulo.html páginas del curso, siempre en la raíz
├─ recursos/
│  └─ ModuloN/Kit_Practica/       fuente original de los archivos descargables del módulo
├─ herramientas/
│  └─ actualizar_kits.ps1         incrusta los kits en el HTML de cada módulo
├─ _respaldos/
│  └─ AAAA-MM-DD_descripcion/     un respaldo = una carpeta con fecha
└─ README.md
```

## Convenciones

- **Páginas:** todas las páginas HTML viven en la raíz y se enlazan entre sí con rutas planas
  (`Modulo2_El_Arte_del_Prompt_Regulatorio.html`). Nombre: `ModuloN_Titulo_Con_Guiones_Bajos.html`.
- **Navegación entre módulos:** al publicar un módulo nuevo hay que actualizar:
  1. La tarjeta en la Bienvenida (de `div.mod-card.is-soon` a `a.mod-card` con `href`).
  2. El menú lateral de los demás módulos (de `span.mod-link.soon` a `a.mod-link`).
  3. `NEXT_MODULE` del módulo anterior y `PREV_MODULE` del nuevo (en el JS de cada página).
- **Archivos descargables:** van incrustados en base64 dentro del HTML (objeto `KIT_FILES`), para
  que cada módulo funcione como un solo archivo, aunque se envíe por correo. La fuente editable
  está en `recursos/ModuloN/Kit_Practica/`.
- **Respaldos:** antes de modificar una página publicada, copiarla a `_respaldos/AAAA-MM-DD_descripcion/`.

## Actualizar un archivo del kit

1. Reemplazar el archivo en `recursos/ModuloN/Kit_Practica/` **con el mismo nombre**.
2. Ejecutar `herramientas/actualizar_kits.ps1` (clic derecho > *Ejecutar con PowerShell*).
   Para un solo módulo: `powershell -ExecutionPolicy Bypass -File herramientas\actualizar_kits.ps1 -Modulo 3`
3. Abrir el módulo, descargar el archivo y comprobar que es la versión nueva.

El script indica qué archivos cambió, avisa si falta alguno (y conserva la versión incrustada) y
señala archivos de la carpeta que el módulo no usa. Si un archivo **cambia de nombre**, además hay
que actualizar su entrada en `KIT_FILES` y los textos del módulo que lo mencionan.

**Visor de documentos (vista previa):** el botón "Ver" de cada archivo abre un visor a pantalla
completa con la lista del kit. PDF se muestra con el visor del navegador; CSV como tabla; Excel con
su versión CSV (mismo nombre, extensión `.csv`); Word con una versión HTML simplificada que el script
genera en el bloque `KIT_PREVIEWS`, así que también se actualiza al ejecutarlo.

Para un módulo nuevo con kit: crear `recursos/ModuloN/Kit_Practica/`, agregar el bloque
`KIT_FILES` en su HTML (mismo formato que el Módulo 3) y ejecutar el script.
