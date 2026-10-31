# Proyecto de ventas e inventario en ensamblador

Sistema de consola en MASM x86 (32 bits) con Irvine32 para administrar un inventario de libros.

## Requisitos

- Windows con Visual Studio (carga de trabajo "Desarrollo para el escritorio con C++")
- Irvine32 instalado en `C:\Irvine`

## Compilación

1. Abrir `ProyectoEnsambladorU2.slnx` con Visual Studio.
2. Seleccionar **Debug** y **x86**.
3. Compilar.
4. Ejecutar.

## Uso

Al ejecutar aparece un menú:

1. Cargar datos existentes
2. Registrar producto
3. Mostrar inventario
4. Buscar por id
5. Recibir mercancia
6. Vender (10% de descuento desde 5 ejemplares)
7. Resumen
8. Guardar
0. Salir

Cada producto tiene id (formato `ABC-123`), nombre, precio en pesos y existencia. El catálogo admite hasta 10 productos y los precios se muestran en MXN con dos decimales. Al salir con cambios sin guardar, el programa pregunta si deseas guardarlos.

## Archivo de inventario

El programa usa `Inventario.txt`, que debe estar en la carpeta del proyecto (o junto al `.exe` si se ejecuta directamente). Se carga con la opción 1 del menú y se guarda con la opción 8.
