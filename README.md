Proyecto Sistema de Seguimiento a Graduados

Aplicación web y móvil para la gestión y seguimiento de graduados de la carrera de Ingeniería Informática.

Descripción del proyecto

El Sistema de Seguimiento a Graduados fue desarrollado como proyecto final del Diplomado UAJMS.

Tecnologías utilizadas
Flutter - Desarrollo de la aplicación móvil.
Dart - Lenguaje de programación.
Supabase - Backend, autenticación y base de datos.
PostgreSQL - Sistema gestor de base de datos.
Provider - Gestión del estado de la aplicación.
SharedPreferences - Persistencia de preferencias locales.
fl_chart - Generación de gráficos estadísticos.
Supabase Auth - Autenticación de usuarios.
Row Level Security (RLS) - Control de acceso a los datos.
Requisitos

Para ejecutar el proyecto se necesita:

Flutter SDK.
Dart SDK.
Android Studio o Visual Studio Code.
Dispositivo Android o emulador.
Cuenta de Supabase.
Proyecto de Supabase configurado.
Instalación

Clonar el repositorio:

bash
git clone URL_DEL_REPOSITORIO

Entrar en la carpeta del proyecto:

bash
cd PROYECTO_Sistema_Seguimiento_Graduado

Configuración de Supabase

Crear un proyecto en Supabase y configurar la autenticación mediante:

Authentication → Email / Password

Posteriormente, ejecutar el script de base de datos incluido en:

text
supabase/01_schema_y_rls.sql

Este script crea las tablas, relaciones, funciones, triggers, índices y políticas RLS necesarias para el funcionamiento del sistema.

Configuración de credenciales

Copiar el archivo de configuración de ejemplo:

bash
cp config/local.example.json config/local.json

Editar el archivo config/local.json con las credenciales del proyecto de Supabase.

Ejecución del proyecto

Instalar las dependencias:

bash
flutter pub get

Ejecutar la aplicación conectada a Supabase:

bash
flutter run --dart-define-from-file=config/local.json

Generar APK de producción

Para generar el APK de producción conectado a Supabase, ejecutar:

bash
flutter build apk --release --dart-define-from-file=config/local.json

El APK generado estará disponible en:

text
build/app/outputs/flutter-apk/app-release.apk
