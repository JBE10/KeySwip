# KeySwip ⌨️🖱️

KeySwip es una herramienta de control remoto que permite transformar tu iPhone en un trackpad y teclado inalámbrico para macOS. Diseñada con un enfoque en la baja latencia, la seguridad y una arquitectura limpia.

## 🚀 Funcionalidades

- **Teclado Remoto**: Escribe en tu Mac desde el iPhone con soporte para caracteres Unicode y teclas especiales (Tab, Delete, Flechas, etc.).
- **Trackpad de Precisión**: Control del cursor con soporte para clicks (izquierdo/derecho) y scroll suave.
- **Conectividad Multipeer**: Conexión automática y segura a través de Wi-Fi o Bluetooth sin necesidad de configuración manual de IPs.
- **Seguridad por Diseño**: Confirmación de conexión obligatoria en el Mac para evitar accesos no autorizados.

## 🛠️ Arquitectura y Tecnologías

El proyecto ha sido refactorizado siguiendo los principios **SOLID**:
- **Single Responsibility Principle (SRP)**: Separación clara entre la capa de comunicación (`MultipeerManager`) y la interpretación de comandos (`CommandRouter`).
- **Inyección de Eventos**: Uso de `CoreGraphics` y `ApplicationServices` para una integración de bajo nivel con el sistema macOS.
- **SwiftUI & Combine**: Interfaz moderna y reactiva tanto en iOS como en la barra de menú de macOS.

## 🔒 Medidas de Seguridad Implementadas

1.  **Aceptación Explícita**: El Mac solicita permiso mediante una alerta nativa antes de permitir cualquier conexión.
2.  **Validación de Eventos**: Los comandos de ratón y teclado son validados y limitados para prevenir inyecciones malintencionadas.
3.  **Cola Serial de Inyección**: Garantiza que los eventos se procesen en orden, evitando condiciones de carrera.

## 📦 Instalación y Requisitos

- **macOS**: Requiere permisos de **Accesibilidad** (Ajustes del Sistema > Privacidad y Seguridad > Accesibilidad).
- **iOS**: Versión 15.0 o superior.
- **Xcode**: 14.0+ para compilación.

## 👨‍💻 Desarrollo

El código está organizado de forma modular:
- `Shared/`: Modelos y lógica de comunicación compartida.
- `macOS/`: Lógica de inyección y gestión de la barra de menú.
- `iOS/`: Interfaz de usuario del teclado y trackpad.

---
*Desarrollado con ❤️ para una productividad sin cables.*
