# Proyecto sistema de seguimiento a gradudos

Aplicación móvil para la gestión y seguimiento de graduados de la carrera de Ingeniería Informática.

# Descripción del proyecto

El Sistema de Seguimiento a Graduados fue desarrollado como proyecto final del Diplomado UAJMS.

# Tecnologías utilizadas

Flutter - Desarrollo de la aplicación móvil.
Dart - Lenguaje de programación.
Supabase - Backend, autenticación y base de datos.
PostgreSQL - Sistema gestor de base de datos.
Provider - Gestión del estado de la aplicación.
SharedPreferences - Persistencia de preferencias locales.
fl_chart - Generación de gráficos estadísticos.
Supabase Auth - Autenticación de usuarios.
Row Level Security (RLS) - Control de acceso a los datos.

# Requisitos

Para ejecutar el proyecto se necesita:

Flutter SDK.
Dart SDK.
Android Studio o Visual Studio Code.
Dispositivo Android o emulador.
Cuenta de Supabase.
Proyecto de Supabase configurado.

# Instalación

Clonar el repositorio:
git clone URL_DEL_REPOSITORIO

# Entrar en la carpeta del proyecto:

cd PROYECTO_Sistema_Seguimiento_Graduado

## 1. Levantar YA sin backend "Modo Demostracion"

```bash
flutter pub get
flutter run --dart-define-from-file=config/demo.json
```

## 2. Conectar Supabase

Configuración de Supabase
Crear un proyecto en Supabase.

Configurar la autenticación mediante:

Authentication
↓
Email / Password
Posteriormente ejecutar el script de base de datos incluido en:
supabase/01_schema_y_rls.sql
Este script crea las tablas, relaciones, funciones, triggers, índices y políticas RLS necesarias para el funcionamiento del sistema.

```bash
cp config/local.example.json config/local.json
# editar local.json con las credenciales de Supabase
flutter run --dart-define-from-file=config/local.json
```

# APK de demostración Modo Demostración

El APK de demostración se encuentra disponible en la sección Releases del repositorio.

También puede generarse localmente mediante:

```bash
flutter build apk --release
```

# APK de producción conectado en Supabase

"ejecutar cuando tengas el supabase configurado"

```bash
flutter build apk --release --dart-define-from-file=config/local.json
```
