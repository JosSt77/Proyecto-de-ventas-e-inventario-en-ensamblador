; Materia: Lenguajes de Interfaz
; Alumnos: López Payán Jorge Emilio, Sotelo Izaguirre José Ángel
; Horario: 10-11
; Docente: Dr. José Luis Medina Jiménez
; Práctica: Proyecto de ventas e inventario en ensamblador
; Descripción: Sistema de consola para administrar hasta 10 productos (libros). Para dar de alta un producto
; se solicita el id (formato ABC-123), el nombre, el precio en pesos mexicanos y la cantidad. El programa permite
; mostrar el inventario, buscar por id, recibir mercancía, vender, mostrar el resumen, guardar y cargar el
; catálogo en un archivo. Los precios se guardan en centavos enteros y se muestran con dos decimales y la
; etiqueta MXN. Como regla adicional se aplica un descuento por cantidad: si en una venta se compran 5 o más
; ejemplares del mismo producto se descuenta el 10% del importe base, descartando la fracción de centavo.

INCLUDE Irvine32.inc

.data
;Buffers usados en el programa
;Estructura de cada producto (44 bytes por registro): +0 id, +8 nombre (max 25 caracteres), +36 precio, +40 cantidad
tabla BYTE 880 DUP(0) ; Espacio para 20 registros (catalogo + temporal)
entrada BYTE 40 DUP(0) ; Buffer entrada de ReadString
numTexto BYTE 12 DUP(0) ; Buffer para conversiones decimales
bufArchivo BYTE 513 DUP(0) ; Buffer de lectura
bufSalida BYTE 600 DUP(0) ; Buffer de escritura

;Variables usadas en el programa
totalProd DWORD 0
tmpTotal DWORD 0
ingresos DWORD 0
cambios DWORD 0
posRegistro DWORD 0
posArchivo DWORD 0
posTmp DWORD 0
contados DWORD 0
importeBase DWORD 0
importeDesc DWORD 0
importeTotal DWORD 0
unidades DWORD 0
valorInv DWORD 0
nombreArchivo BYTE "Inventario.txt", 0
archivoHandle DWORD ?
bytesLeidos DWORD 0
bytesEsperados DWORD 0

;Mensajes para el menú
msgBienvenida BYTE "LIBRERIA EN LINEA",0
msgMenu BYTE 0dh, 0ah, "1. Cargar datos existentes", 0dh, 0ah,
             "2. Registrar producto", 0dh, 0ah,
             "3. Mostrar inventario", 0dh, 0ah,
             "4. Buscar por id", 0dh, 0ah,
             "5. Recibir mercancia", 0dh, 0ah,
             "6. Vender (10% de descuento desde 5 ejemplares)", 0dh, 0ah,
             "7. Resumen", 0dh, 0ah,
             "8. Guardar", 0dh, 0ah,
             "0. Salir", 0dh, 0ah, 0

msgOpcion BYTE "Opcion: ", 0
msgId BYTE "Ingrese el id: ", 0
msgNombre BYTE "Ingrese el nombre (max 25 caracteres): ", 0
msgPrecio BYTE "Ingrese el precio en MXN: ", 0
msgCantidad BYTE "Ingrese la cantidad (max 100): ", 0
msgCantRec BYTE "Ingrese las unidades recibidas: ", 0
msgCantVta BYTE "Ingrese la cantidad a vender: ", 0
msgPreguntaGuardar BYTE "Hay cambios sin guardar. Desea guardar s/n? ", 0

;Mensajes para mostrar resultados
msgSep BYTE ", ", 0
msgCantLbl BYTE ", Cantidad: ", 0
msgPeso BYTE "$", 0
msgPunto BYTE ".", 0
msgCero BYTE "0", 0
msgMXN BYTE " MXN", 0
msgBaseLbl BYTE "Importe base: ", 0
msgDescLbl BYTE "Descuento 10%: -", 0
msgTotalLbl BYTE "Total: ", 0
msgNuevaExist BYTE "Nueva existencia: ", 0
msgProductos BYTE "Productos registrados: ", 0
msgUnidades BYTE "Unidades disponibles: ", 0
msgValor BYTE "Valor del inventario: ", 0
msgIngresos BYTE "Ingresos de la sesion: ", 0
salto BYTE 0dh, 0ah, 0

;Mensajes para los distintos errores
msgOpcionMal BYTE "Opcion invalida", 0dh, 0ah, 0
msgVacio BYTE "El dato no puede estar vacio.", 0dh, 0ah, 0
msgIdMal BYTE "Id invalido, use 3 letras mayusculas, un guion y 3 digitos.", 0dh, 0ah, 0
msgNombreMal BYTE "Nombre invalido, use de 1 a 25 caracteres.", 0dh, 0ah, 0
msgPrecioMal BYTE "Precio invalido.", 0dh, 0ah, 0
msgNumMal BYTE "Numero invalido.", 0dh, 0ah, 0
msgCantCero BYTE "La cantidad debe ser mayor que cero.", 0dh, 0ah, 0
msgLleno BYTE "El catalogo esta lleno.", 0dh, 0ah, 0
msgDuplicado BYTE "Ya existe un producto con ese id.", 0dh, 0ah, 0
msgNoExiste BYTE "No existe un producto con ese id.", 0dh, 0ah, 0
msgSinProductos BYTE "No hay productos registrados.", 0dh, 0ah, 0
msgExcede BYTE "La existencia no puede pasar de 100 unidades.", 0dh, 0ah, 0
msgSinExist BYTE "No hay existencias suficientes.", 0dh, 0ah, 0
msgDesborda BYTE "Desbordamiento, la operacion se cancelo.", 0dh, 0ah, 0
msgOk BYTE "Operacion realizada exitosamente.", 0dh, 0ah, 0

;Mensajes para cuando se guarda un archivo
msgGuardado BYTE "Catalogo guardado correctamente.", 0dh, 0ah, 0
msgNoGuardado BYTE "No se pudo guardar el archivo.", 0dh, 0ah, 0
msgNoArchivo BYTE "No se encontro el archivo.", 0dh, 0ah, 0
msgArchivoMal BYTE "Archivo invalido, el catalogo no cambio.", 0dh, 0ah, 0
msgErrLectura BYTE "Error al leer el archivo.", 0dh, 0ah, 0

.code
main PROC

    mov edx, OFFSET msgBienvenida ; Se muestra el mensaje de bienvenida
    call WriteString

    menu: ;Ciclo del menú principal
        mov edx, OFFSET msgMenu
        call WriteString
        mov edx, OFFSET msgOpcion
        call PedirCadena ; Se captura la opción, EAX regresa la longitud
        cmp eax, 1 ; La opción debe ser un solo carácter
        jne opcionMala
        mov al, entrada[0]
        sub al, '0' ; Se convierte el carácter ASCII en su valor numérico
        cmp al, 1 ; Opción 1: cargar
        je opc1
        cmp al, 2 ; Opción 2: registrar
        je opc2
        cmp al, 3 ; Opción 3: mostrar el inventario
        je opc3
        cmp al, 4 ; Opción 4: buscar
        je opc4
        cmp al, 5 ; Opción 5: recibir mercancía
        je opc5
        cmp al, 6 ; Opción 6: vender
        je opc6
        cmp al, 7 ; Opción 7: resumen
        je opc7
        cmp al, 8 ; Opción 8: guardar
        je opc8
        cmp al, 0 ; Opción 0: salir
        je salir

    opcionMala: ;Función cuando la opción no es válida
        mov edx, OFFSET msgOpcionMal
        call WriteString
        jmp menu

    opc1:
        call Cargar
        jmp menu
    opc2:
        call Registrar
        jmp menu
    opc3:
        call MostrarInventario
        jmp menu
    opc4:
        call Buscar
        jmp menu
    opc5:
        call Recibir
        jmp menu
    opc6:
        call Vender
        jmp menu
    opc7:
        call Resumen
        jmp menu
    opc8:
        call Guardar
        jmp menu

    salir: ;Antes de terminar se revisa si hay cambios sin guardar
        cmp cambios, 0
        je terminar
        mov edx, OFFSET msgPreguntaGuardar
        call PedirCadena
        mov al, entrada[0]
        cmp al, 's'
        je guardarSalir
        cmp al, 'S'
        je guardarSalir
        jmp terminar ; Cualquier otra respuesta termina sin guardar

    guardarSalir:
        call Guardar

    terminar:
        exit

main ENDP

convertirDecimal PROC
    ;Entradas: EAX = número, ESI = dirección del buffer de al menos 11 bytes
        push eax
        push ebx
        push ecx
        push edx
        push esi
        mov ecx, 0 ; Contador de dígitos

    extraerDigitos:
        mov edx, 0
        mov ebx, 10 ; Divisor para extraer el último dígito
        div ebx ; Cociente en EAX y residuo (dígito) en EDX
        push edx ; Se apila el dígito
        inc ecx
        cmp eax, 0
        jne extraerDigitos

    construirCadena:
        pop edx ; Los dígitos salen en orden LIFO
        add dl, '0' ; Se convierte el dígito en su carácter ASCII
        mov [esi], dl
        inc esi
        loop construirCadena

        mov dl, 0 ; Terminador nulo
        mov [esi], dl

        pop esi
        pop edx
        pop ecx
        pop ebx
        pop eax
        ret
convertirDecimal ENDP

MostrarNumero PROC ;Convierte un número a cadena decimal y lo muestra en pantalla
    ;Entradas: EAX = número
    ;Registros modificados: ninguno
    push edx ; Se guardan los registros que este procedimiento modifica
    push esi
    mov esi, OFFSET numTexto ; ESI apunta al buffer donde se escribirá la cadena
    call convertirDecimal ; Se convierte el número de EAX en texto dentro de numTexto
    mov edx, OFFSET numTexto ; WriteString imprime la cadena a la que apunta EDX
    call WriteString
    pop esi ; Se restauran en orden inverso al que se guardaron
    pop edx
    ret
MostrarNumero ENDP

MostrarMXN PROC ;Muestra un importe en centavos con el formato $pesos.centavos MXN
    ;Entradas: EAX = importe en centavos
    ;Registros modificados: ninguno
    push eax ; Se guardan los valores iniciales
    push ebx
    push edx

    mov edx, 0 ; Se limpia EDX porque div usa EDX:EAX como dividendo
    mov ebx, 100 ;Se asigna 100 para comenzar la división
    div ebx ; EAX queda con los pesos y EDX con los centavos
    push edx ; Se guardan los centavos mientras se imprimen los pesos

    mov edx, OFFSET msgPeso ; Símbolo $
    call WriteString
    call MostrarNumero ; Se muestran los pesos que están en EAX
    mov edx, OFFSET msgPunto ; Punto decimal
    call WriteString

    pop eax ; EAX recibe los centavos
    cmp eax, 10 ; Con dos dígitos no hace falta relleno
    jae dosDigitos
    mov edx, OFFSET msgCero ; Relleno: 5 se muestra como 05
    call WriteString

    dosDigitos:
        call MostrarNumero ; Se muestran los centavos
        mov edx, OFFSET msgMXN ; Etiqueta de la moneda
        call WriteString

        pop edx ; Se restauran los valores iniciales
        pop ebx
        pop eax
        ret
MostrarMXN ENDP

PedirCadena PROC ;Muestra un mensaje y captura una cadena con ReadString
    ;Salidas: la cadena queda en entrada y EAX = longitud capturada
    ;Registros modificados: EAX, ECX, EDX
    call WriteString
    mov edx, OFFSET entrada ; Buffer donde se guardará la entrada
    mov ecx, SIZEOF entrada ; Límite máximo de lectura
    call ReadString ; EAX regresa la cantidad de caracteres leídos
    ret
PedirCadena ENDP

PedirDato PROC ;Proceso para pedir datos
    ;Salidas: EAX = 1 si capturó algo (queda en entrada), 0 si está vacía (muestra el error)
    ;Registros modificados: EAX, ECX, EDX

    call PedirCadena 
    cmp eax, 0
    jne datoCapturado
    mov edx, OFFSET msgVacio
    call WriteString
    mov eax, 0
    ret

    datoCapturado:
        mov eax, 1
        ret
PedirDato ENDP

ValidarId PROC ;Revisa que entrada tenga el formato ABC-123: 3 letras mayúsculas, un guion y 3 dígitos
    ;Salidas: EAX = 1 si el id es válido, 0 si no lo es
    ;Registros modificados: EAX (ECX y ESI se restauran)
    push ecx ; Se guardan los registros que se usan como contador e índice
    push esi
    mov esi, 0 ; ESI es el índice dentro de entrada
    mov ecx, 3 ; Se revisan las posiciones 0, 1 y 2
    corroborarLetras:
        mov al, entrada[esi] ;Se recorre el índice para confirmar que lo que se encuentra en las posiciones 0, 1 y 2
        cmp al, 'A' ;sean solo letras mayúsculas (de la A a la Z)
        jb idInvalido
        cmp al, 'Z'
        ja idInvalido
        inc esi
        loop corroborarLetras ;se repite el ciclo hasta que terminen las 3 posiciones

        mov al, entrada[3] ; Separador en la posición 4 (índice 3)
        cmp al, '-'
        jne idInvalido
        mov esi, 4 ; El índice se coloca después del guion
        mov ecx, 3 ; Se revisan las posiciones 5, 6 y 7 (índices 4, 5 y 6)

    cicloDigitos:
        mov al, entrada[esi]
        cmp al, '0' ;Se confirma que los últimos tres caracteres sean dígitos del 0 al 9
        jb idInvalido
        cmp al, '9'
        ja idInvalido
        inc esi ;se incrementa el índice para pasar al siguiente dígito
        loop cicloDigitos

        mov al, entrada[7] ; Debe ser el fin de la cadena, así el id mide exactamente 7 caracteres
        cmp al, 0
        jne idInvalido
        mov eax, 1 ; Id válido
        jmp finValidarId

    idInvalido: ;Se retorna en caso de ser inválido
        mov eax, 0

    finValidarId:
        pop esi ; Se restauran los valores iniciales
        pop ecx
        ret
ValidarId ENDP

ValidarNombre PROC ;Revisa que entrada tenga de 1 a 25 caracteres imprimibles
    ;Salidas: EAX = 1 si es válido, 0 si no lo es
    push ecx
    push esi

    mov esi, 0
    mov ecx, 0 ; ECX cuenta la longitud del nombre

    cicloNombre:
        mov al, entrada[esi]
        cmp al, 0 ;Compara que se haya llegado al final de la cadena del nombre
        je finNombre
        cmp al, 32 ; Solo se aceptan caracteres imprimibles (32 a 126)
        jb nombreInvalido
        cmp al, 126
        ja nombreInvalido
        inc ecx ;se incrementa el valor de la longitud del nombre
        inc esi ;se incrementa el índice que recorre
        jmp cicloNombre

    finNombre:
        cmp ecx, 1 ;Se confirma que el nombre tenga una longitud de 1 a 25 caracteres
        jb nombreInvalido
        cmp ecx, 25
        ja nombreInvalido
        mov eax, 1
        jmp salirValidarNombre

    nombreInvalido:
        mov eax, 0

    salirValidarNombre:
        pop esi ;se retornan los valores iniciales
        pop ecx
        ret

ValidarNombre ENDP

ConvertirEntero PROC ;Convierte la cadena de entrada en número con la fórmula acumulado x 10 + dígito

    push edx ;Se guardan valores iniciales
    push esi

    mov esi, 0
    mov ecx, 0 ; ECX es el acumulador
    mov al, entrada[0] ;se compara con el primer dígito del buffer entrada
    cmp al, 0 ; Una cadena vacía se rechaza
    je enteroMalo

    cicloEntero: ;Si es número, entonces se procede a realizar el ciclo de conversión
        mov al, entrada[esi]
        cmp al, 0
        je enteroBueno
        cmp al, '0'  ;Se compara que la cadena esté entre los rangos de caracter de 0 a 9
        jb enteroMalo
        cmp al, '9'
        ja enteroMalo
        mov eax, ecx
        mov edx, 10
        mul edx ; EAX = acumulado x 10
        mov ecx, eax
        mov al, entrada[esi] ;se asigna el valor del índice del buffer
        sub al, '0' ; Se convierte el ASCII en su valor de 0 a 9
        mov edx, 0
        mov dl, al
        add ecx, edx ; Se suma el dígito
        cmp ecx, ebx ; No debe pasar del máximo
        ja enteroMalo
        inc esi
        jmp cicloEntero

    enteroBueno:
        mov eax, 1 ;se marca como operación exitosa
        jmp finEntero

    enteroMalo:
        mov eax, 0

    finEntero:
        pop esi ;se retorna los valores iniciales
        pop edx
        ret
ConvertirEntero ENDP

ConvertirPrecio PROC
    ;Acepta pesos enteros o un punto con uno o dos decimales, rechaza símbolos y un tercer decimal
    ;Todos los dígitos se acumulan en un solo número y al final se ajusta según los decimales escritos
    ;Salidas: EAX = 1 si es válido o 0 si no lo es, ECX = centavos de 1 a 999999
    ;Registros modificados: EAX, ECX
    push ebx ; Se guardan los registros que se usan como contadores y apoyo
    push edx
    push esi
    push edi

    mov esi, 0 ; ESI es el índice dentro de entrada
    mov ecx, 0 ; ECX acumula todos los dígitos como un solo número
    mov ebx, 0 ; EBX cuenta los dígitos de los pesos
    mov edi, 0 ; EDI: 0 sin punto, 1 punto sin decimales, 2 un decimal, 3 dos decimales

    cicloPrecio:
        mov al, entrada[esi]
        cmp al, 0 ; Fin de la cadena
        je finCadenaPrecio
        cmp al, '.' ; Se encontró el punto decimal
        je puntoPrecio
        cmp al, '0' ; Cualquier otro carácter debe ser un dígito
        jb precioMalo
        cmp al, '9'
        ja precioMalo
        mov eax, ecx
        mov edx, 10
        mul edx ; EAX = acumulado x 10
        mov ecx, eax
        mov al, entrada[esi]
        sub al, '0' ; Se convierte el ASCII en su valor de 0 a 9
        mov edx, 0
        mov dl, al
        add ecx, edx ; Se suma el dígito
        cmp ecx, 999999 ; Si ya pasa del máximo se rechaza (también evita desbordar)
        ja precioMalo
        cmp edi, 0 ; Si todavía no hay punto, el dígito es de los pesos
        jne decimalPrecio
        inc ebx ; Es un dígito de los pesos
        jmp siguientePrecio

    decimalPrecio:
        inc edi ; Es un dígito de los decimales
        cmp edi, 3 ; Un tercer decimal se rechaza
        ja precioMalo

    siguientePrecio:
        inc esi ; Se pasa al siguiente carácter
        jmp cicloPrecio

    puntoPrecio:
        cmp edi, 0 ; Solo se permite un punto
        jne precioMalo
        cmp ebx, 0 ; Debe haber al menos un dígito antes del punto
        je precioMalo
        mov edi, 1 ; Se marca que ya apareció el punto
        inc esi
        jmp cicloPrecio

    finCadenaPrecio:
        cmp ebx, 0 ; Debe haber al menos un dígito de pesos
        je precioMalo
        cmp edi, 1 ; Un punto sin decimales se rechaza
        je precioMalo
        mov eax, ecx ; EAX = todos los dígitos juntos
        cmp edi, 3 ; Con dos decimales el acumulado ya son centavos
        je precioListo
        mov edx, 100 ; Sin punto: pesos x 100
        cmp edi, 0
        je escalarPrecio
        mov edx, 10 ; Con un decimal: 7.5 son 75 x 10 = 750 centavos

    escalarPrecio:
        mul edx ; EAX = acumulado x factor (100 o 10)

    precioListo:
        mov ecx, eax ; ECX regresa los centavos
        cmp ecx, 1 ; El mínimo es 1 centavo
        jb precioMalo
        cmp ecx, 999999 ; El máximo es 9999.99 pesos
        ja precioMalo
        mov eax, 1 ; Precio válido
        jmp finPrecio

    precioMalo:
        mov eax, 0

    finPrecio:
        pop edi ; Se restauran los valores iniciales
        pop esi
        pop edx
        pop ebx
        ret
ConvertirPrecio ENDP

PedirId PROC ;Pide un id y verifica que tenga el formato correcto
    ;Salidas: EAX = 1 si el id es válido (queda en entrada), 0 si no lo es (muestra el error)
    ;Entradas: EDX = mensaje que se muestra al pedir el dato
    call PedirDato ; Captura la cadena, EAX = 1 si no está vacía
    cmp eax, 1
    jne finPedirId ; Si estaba vacía PedirDato ya mostró el error
    call ValidarId ; Se revisa el formato ABC-123
    cmp eax, 1
    je finPedirId
    mov edx, OFFSET msgIdMal
    call WriteString
    mov eax, 0 ; Se indica que el id no es válido

    finPedirId:
        ret
PedirId ENDP

PedirEntero PROC ;Pide un número entero y verifica que sea válido y no pase del máximo
    ;Entradas: EDX = mensaje que se muestra al pedir el dato, EBX = valor máximo permitido
    ;Salidas: EAX = 1 si es válido o 0 si no lo es, ECX = número capturado
    call PedirDato ; Captura la cadena, EAX = 1 si no está vacía
    cmp eax, 1
    jne finPedirEntero ; Si estaba vacía PedirDato ya mostró el error
    call ConvertirEntero ; Convierte la cadena en número, el resultado queda en ECX
    cmp eax, 1
    je finPedirEntero
    mov edx, OFFSET msgNumMal
    call WriteString
    mov eax, 0 ; Se indica que el número no es válido

    finPedirEntero:
    ret
PedirEntero ENDP

CopiarEntrada PROC ;Copia la cadena de entrada, con su 00h, dentro de la tabla
    ;Entradas: ESI = posición de la tabla donde se escribirá la cadena
    ;Registros modificados: ninguno

        push eax ; Se guardan los valores iniciales
        push esi
        push edi

        mov edi, 0 ; EDI es el índice de la cadena de entrada

    cicloCopia:
        mov al, entrada[edi] ; Se toma un carácter de entrada
        mov tabla[esi], al ; Se escribe en la tabla
        inc esi
        inc edi
        cmp al, 0 ; El ciclo termina después de copiar el 00h final
        jne cicloCopia

        pop edi ; Se restauran los valores iniciales
        pop esi
        pop eax
        ret
CopiarEntrada ENDP

BuscarId PROC ;Recorre registros de la tabla con ESI buscando el id que está en entrada
    ;Salidas: EAX = 1 si lo encontró (ESI = posición de su registro) o 0 si no lo encontró
    ;Registros modificados: EAX, ESI
    ;se guardan valores iniciales
    push ebx
    push ecx
    push edi

    cmp ecx, 0 ; Sin registros no se encuentra
    je noHallado

    siguienteRegistro:
        push esi ; Se guarda la posición donde empieza el registro
        mov edi, 0 ; EDI es el índice del id buscado

    compararCaracter:
        mov al, tabla[esi] ; Carácter del id guardado
        mov bl, entrada[edi] ; Carácter del id buscado
        cmp al, bl
        jne distinto
        cmp al, 0 ; Iguales hasta el final: los ids son iguales
        je hallado
        inc esi ;se incrementan los índices
        inc edi
        jmp compararCaracter

    distinto:
        pop esi ; Se recupera el inicio del registro
        add esi, 44 ; Siguiente registro
        loop siguienteRegistro

    noHallado:
        mov eax, 0
        jmp finBuscarId

    hallado:
        pop esi ; ESI regresa al inicio del registro encontrado
        mov eax, 1

    finBuscarId:
        pop edi
        pop ecx
        pop ebx
        ret
BuscarId ENDP

PedirProducto PROC ;Pide un id y busca el producto en el catálogo
    ;Salidas: EAX = 1 si el producto existe (ESI = posición de su registro), 0 si no
    ;Registros modificados: EAX, ECX, EDX, ESI
    mov edx, OFFSET msgId
    call PedirId ; Se pide y valida el formato del id
    cmp eax, 1
    jne finPedirProducto
    mov esi, 0 ; La búsqueda inicia en el primer registro
    mov ecx, totalProd ; Se revisan tantos registros como productos haya
    call BuscarId ; ESI regresa con la posición del registro si lo encuentra
    cmp eax, 1
    je finPedirProducto
    mov edx, OFFSET msgNoExiste
    call WriteString
    mov eax, 0 ; Se indica que el producto no existe

    finPedirProducto:
        ret

PedirProducto ENDP

MostrarProducto PROC 
    ;se guardan los valores iniciales
    push eax
    push edx

    mov edx, OFFSET tabla
    add edx, esi ; El id está en el desplazamiento +0
    call WriteString
    mov edx, OFFSET msgSep ;se agregan comas
    call WriteString
    mov edx, OFFSET tabla
    add edx, esi
    add edx, 8 ; El nombre está en el desplazamiento +8
    call WriteString
    mov edx, OFFSET msgSep
    call WriteString
    mov eax, DWORD PTR tabla[esi+36] ; Precio en el desplazamiento +36
    call MostrarMXN
    mov edx, OFFSET msgCantLbl
    call WriteString
    mov eax, DWORD PTR tabla[esi+40] ; Cantidad en el desplazamiento +40
    call MostrarNumero
    call Crlf

    pop edx ;se retornan valores
    pop eax
    ret
MostrarProducto ENDP

Registrar PROC ;Da de alta un producto pidiendo id, nombre, precio y cantidad
    ;Los datos se escriben en el primer registro libre, pero el producto solo cuenta cuando
    ;todos son válidos y se incrementa totalProd. Si algún dato es inválido no cambia el catálogo
    ;Registros modificados: ninguno
    push eax ;se guardan los valores
    push ebx
    push ecx
    push edx
    push esi

    cmp totalProd, 10 ; Capacidad máxima
    jb hayLugar ;comparar si hay espacio
    mov edx, OFFSET msgLleno
    call WriteString
    jmp finRegistrar

    hayLugar:
        mov edx, OFFSET msgId
        call PedirId ; Se pide y valida el id
        cmp eax, 1
        jne finRegistrar
        mov esi, 0
        mov ecx, totalProd
        call BuscarId ; ¿El id ya existe?
        cmp eax, 1
        jne idLibre
        mov edx, OFFSET msgDuplicado
        call WriteString
        jmp finRegistrar

    idLibre:
        mov eax, totalProd
        mov ebx, 44 ; Tamaño de cada registro
        mul ebx ; EAX = posición del primer registro libre
        mov posRegistro, eax ; Se guarda la posición porque ESI se modifica más adelante
        mov esi, eax
        call CopiarEntrada ; Se guarda el id en el desplazamiento +0

        mov edx, OFFSET msgNombre
        call PedirDato ; Se pide el nombre, queda en entrada
        cmp eax, 1
        jne finRegistrar
        call ValidarNombre ; Se revisa que tenga de 1 a 25 caracteres imprimibles
        cmp eax, 1
        je nombreBueno
        mov edx, OFFSET msgNombreMal
        call WriteString
        jmp finRegistrar

    nombreBueno:
        mov esi, posRegistro
        add esi, 8 ; El nombre va en el desplazamiento +8
        call CopiarEntrada

        mov edx, OFFSET msgPrecio
        call PedirDato ; Se pide el precio, queda en entrada
        cmp eax, 1
        jne finRegistrar
        call ConvertirPrecio ; Los centavos regresan en ECX
        cmp eax, 1
        je precioBueno
        mov edx, OFFSET msgPrecioMal
        call WriteString
        jmp finRegistrar

    precioBueno:
        mov esi, posRegistro
        mov DWORD PTR tabla[esi+36], ecx ; Precio en el desplazamiento +36

        mov edx, OFFSET msgCantidad
        mov ebx, 100 ; La cantidad máxima es 100
        call PedirEntero ; La cantidad regresa en ECX
        cmp eax, 1
        jne finRegistrar
        mov esi, posRegistro
        mov DWORD PTR tabla[esi+40], ecx ; Cantidad en el desplazamiento +40

        inc totalProd ; Todos los datos son válidos, se cuenta un producto más
        mov cambios, 1 ; Se marca que hay cambios sin guardar
        mov edx, OFFSET msgOk
        call WriteString

    finRegistrar:
        pop esi ; Se restauran los valores iniciales
        pop edx
        pop ecx
        pop ebx
        pop eax
        ret
Registrar ENDP

MostrarInventario PROC ;Muestra todos los productos registrados, uno por línea
    ;Registros modificados: ninguno
    push ecx ; Se guardan los valores iniciales
    push edx
    push esi

    cmp totalProd, 0 ;se comprueba que existan productos
    jne hayProductos
    mov edx, OFFSET msgSinProductos
    call WriteString
    jmp finMostrar

    hayProductos:
        mov esi, 0 ; ESI es la posición del registro que se muestra
        mov ecx, totalProd ; ECX controla cuántos registros faltan

    cicloMostrar:
        call MostrarProducto ; Se imprime el registro al que apunta ESI
        add esi, 44 ; Siguiente registro
        loop cicloMostrar

    finMostrar:
        pop esi ; Se restauran los valores iniciales
        pop edx
        pop ecx
        ret
MostrarInventario ENDP

Buscar PROC
    push eax
    push ecx
    push edx
    push esi

    call PedirProducto ;se llama al metodo para pedir el id
    cmp eax, 1
    jne finBuscar
    call MostrarProducto ; ESI apunta al producto encontrado

    finBuscar:
        pop esi
        pop edx
        pop ecx
        pop eax
        ret
Buscar ENDP

Recibir PROC ;Suma unidades a un producto existente sin pasar de 100
    ;Registros modificados: ninguno

    push eax ;se guardan los valores
    push ebx
    push ecx
    push edx
    push esi

    call PedirProducto ;se llama al método para buscar el id
    cmp eax, 1 ;se comprueba que se haya retornado algo válido
    jne finRecibir
    mov edx, OFFSET msgCantRec
    mov ebx, 1000000 ; Valor máximo que se acepta capturar
    call PedirEntero ; ECX regresa la cantidad
    cmp eax, 1
    jne finRecibir
    cmp ecx, 0 ; No se permite recibir cero unidades
    jne cantidadRecibida
    mov edx, OFFSET msgCantCero
    call WriteString
    jmp finRecibir

    cantidadRecibida:
        mov eax, DWORD PTR tabla[esi+40] ; Existencia actual
        add eax, ecx ; No desborda porque son máximo 1000100
        cmp eax, 100 ; La existencia no puede pasar de 100
        jbe aplicarEntrada
        mov edx, OFFSET msgExcede
        call WriteString
        jmp finRecibir

    aplicarEntrada:
        mov DWORD PTR tabla[esi+40], eax ; Se guarda la nueva existencia
        mov cambios, 1 ; Se marca que hay cambios sin guardar
        mov edx, OFFSET msgNuevaExist
        call WriteString
        call MostrarNumero ; Se muestra la nueva existencia que está en EAX
        call Crlf

    finRecibir:
        pop esi ; Se restauran los valores iniciales
        pop edx
        pop ecx
        pop ebx
        pop eax
        ret
Recibir ENDP

Vender PROC
    ;Primero se validan todos los datos y hasta el final se actualizan existencias e ingresos
    ;Regla adicional: con 5 o más ejemplares se descuenta el 10% del importe base y se descarta
    ;la fracción de centavo. Si la venta se rechaza no cambia ningún dato

    push eax ;se guardan valores inicales
    push ebx
    push ecx
    push edx
    push esi

    call PedirProducto ;se llama al método
    cmp eax, 1 ;se válida el estado de válido
    jne finVender
    mov edx, OFFSET msgCantVta
    mov ebx, 1000000 ; Valor máximo que se acepta capturar
    call PedirEntero ; ECX regresa la cantidad
    cmp eax, 1
    jne finVender
    cmp ecx, 0
    jne ventaCantidad
    mov edx, OFFSET msgCantCero
    call WriteString
    jmp finVender

    ventaCantidad:
        cmp ecx, DWORD PTR tabla[esi+40] ; Cantidad contra existencia
        jbe hayExistencia ;en caso que haya existencia salta a la operación
        mov edx, OFFSET msgSinExist
        call WriteString
        jmp finVender

    hayExistencia:
        mov eax, DWORD PTR tabla[esi+36] ; Precio en centavos
        mul ecx ; EDX:EAX = precio x cantidad
        cmp edx, 0 ; Si EDX no es 0 no cabe en 32 bits
        jne ventaDesborda
        mov importeBase, eax
        mov importeDesc, 0
        cmp ecx, 5 ; Regla adicional: 5 o más ejemplares
        jb sinDescuento
        mov ebx, 10
        mul ebx ; EAX = importe base x 10
        cmp edx, 0
        jne ventaDesborda
        mov edx, 0
        mov ebx, 100
        div ebx ; EAX = base x 10 / 100, el residuo se descarta
        mov importeDesc, eax

    sinDescuento:
        mov eax, importeBase
        sub eax, importeDesc ; Total = importe base - descuento
        mov importeTotal, eax
        mov eax, ingresos
        add eax, importeTotal ; Se suma la venta a los ingresos de la sesión
        jc ventaDesborda ; Si hay acarreo no cabe en 32 bits y se cancela

        mov ingresos, eax ; Venta aceptada: ahora sí se actualizan los datos
        mov eax, DWORD PTR tabla[esi+40]
        sub eax, ecx ; Existencia = existencia - cantidad vendida
        mov DWORD PTR tabla[esi+40], eax
        mov cambios, 1 ; Se marca que hay cambios sin guardar

        mov edx, OFFSET msgBaseLbl
        call WriteString
        mov eax, importeBase
        call MostrarMXN ; Se muestra el importe base
        call Crlf
        cmp ecx, 5
        jb mostrarTotal ; Con menos de 5 no hubo descuento
        mov edx, OFFSET msgDescLbl
        call WriteString
        mov eax, importeDesc
        call MostrarMXN ; Se muestra el descuento
        call Crlf

    mostrarTotal:
        mov edx, OFFSET msgTotalLbl
        call WriteString
        mov eax, importeTotal
        call MostrarMXN ; Se muestra el total a pagar
        call Crlf
        jmp finVender

    ventaDesborda:
        mov edx, OFFSET msgDesborda ; Ningún dato se modificó, la venta se cancela
        call WriteString

    finVender:
        pop esi ; Se restauran los valores iniciales
        pop edx
        pop ecx
        pop ebx
        pop eax
        ret
Vender ENDP

Resumen PROC ;Muestra las unidades disponibles, el valor del inventario y los ingresos de la sesión
    push eax ;se guardan valores iniciales 
    push ecx
    push edx
    push esi

    mov unidades, 0 ;se inicializan los valores
    mov valorInv, 0
    mov esi, 0
    mov ecx, totalProd
    cmp ecx, 0
    je imprimirResumen

    cicloResumen:
        mov eax, DWORD PTR tabla[esi+40] ; Existencia del producto
        add unidades, eax
        mov eax, DWORD PTR tabla[esi+36] ; Precio del producto
        mov edx, DWORD PTR tabla[esi+40]
        mul edx ; EDX:EAX = precio x existencia
        cmp edx, 0 ; Si EDX no es 0 no cabe en 32 bits
        jne resumenDesborda
        add valorInv, eax
        jc resumenDesborda
        add esi, 44
        loop cicloResumen

    imprimirResumen:
        mov edx, OFFSET msgProductos
        call WriteString
        mov eax, totalProd
        call MostrarNumero
        call Crlf
        mov edx, OFFSET msgUnidades
        call WriteString
        mov eax, unidades
        call MostrarNumero
        call Crlf
        mov edx, OFFSET msgValor
        call WriteString
        mov eax, valorInv
        call MostrarMXN
        call Crlf
        mov edx, OFFSET msgIngresos
        call WriteString
        mov eax, ingresos
        call MostrarMXN
        call Crlf
        jmp finResumen

    resumenDesborda:
        mov edx, OFFSET msgDesborda
        call WriteString

    finResumen:
        pop esi
        pop edx
        pop ecx
        pop eax
        ret
Resumen ENDP

AgregarCadena PROC ;Agrega una cadena, sin su 00h, al buffer bufSalida
    ;Entradas: EDX = dirección de la cadena, EBX = posición actual dentro de bufSalida
    ;Salidas: EBX avanzado al final de lo agregado
    ;Registros modificados: EBX (se deja modificado a propósito para seguir escribiendo)
    push eax ; Se guardan los valores iniciales
    push edx

    cicloAgregar:
    mov al, [edx] ; Se toma un carácter de la cadena
    cmp al, 0 ; El 00h no se copia
    je finAgregar
    mov bufSalida[ebx], al ; Se escribe en el buffer de salida
    inc ebx ; EBX avanza en el buffer
    inc edx ; EDX avanza en la cadena
    jmp cicloAgregar

    finAgregar:
    pop edx ; Se restauran EAX y EDX, EBX conserva la nueva posición
    pop eax
    ret
AgregarCadena ENDP

AgregarLinea PROC ;Agrega una cadena y un salto de línea al buffer bufSalida
    ;Entradas: EDX = dirección de la cadena, EBX = posición actual dentro de bufSalida
    ;Salidas: EBX avanzado al final de lo agregado
    push edx ; Se guarda EDX porque se cambia para apuntar al salto de línea
    call AgregarCadena ; Se agrega la cadena
    mov edx, OFFSET salto
    call AgregarCadena ; Se agrega el 0Dh 0Ah
    pop edx ; EDX regresa a la dirección original de la cadena
    ret
AgregarLinea ENDP

AgregarNumero PROC ;Convierte un número en cadena decimal y la agrega al buffer con un salto de línea
    ;Entradas: EAX = número, EBX = posición actual dentro de bufSalida
    ;Salidas: EBX avanzado al final de lo agregado
    push edx ; Se guardan los valores iniciales
    push esi

    mov esi, OFFSET numTexto ; Buffer donde se escribe la cadena decimal
    call convertirDecimal ; Se convierte EAX en texto
    mov edx, OFFSET numTexto
    call AgregarLinea ; Se agrega el texto y un salto de línea al buffer de salida

    pop esi ; Se restauran los valores iniciales
    pop edx
    ret
AgregarNumero ENDP

Guardar PROC ;Guarda el catálogo en el archivo de texto Inventario.txt
    ;Cada dato va en su propia línea: primero el total de productos y después, por cada
    ;producto, el id, el nombre, el precio en centavos y la cantidad
    push eax ;se guardan los valores
    push ebx
    push ecx
    push edx
    push esi

    mov ebx, 0 ; EBX es la posición dentro de bufSalida
    mov eax, totalProd ;se guarda la cantidad total de productos
    call AgregarNumero
    mov esi, 0
    mov ecx, totalProd
    cmp ecx, 0
    je escribirArchivo ; Sin productos solo se escribe el total

    cicloGuardar:
        mov edx, OFFSET tabla
        add edx, esi ; El id está en el desplazamiento +0
        call AgregarLinea
        add edx, 8 ; El nombre está en el desplazamiento +8
        call AgregarLinea
        mov eax, DWORD PTR tabla[esi+36] ; Precio en centavos
        call AgregarNumero
        mov eax, DWORD PTR tabla[esi+40] ; Cantidad
        call AgregarNumero
        add esi, 44 ;se va incrementando el índice
        dec ecx
        jne cicloGuardar

    escribirArchivo:
        mov bytesEsperados, ebx ; EBX es el total de bytes que se armaron en bufSalida
        mov edx, OFFSET nombreArchivo
        call CreateOutputFile ; Se devuelve el identificador a EAX
        cmp eax, INVALID_HANDLE_VALUE ;se confirma que no exista error
        je errorGuardar
        mov archivoHandle, eax ; Se guarda el identificador del archivo

        mov eax, archivoHandle
        mov edx, OFFSET bufSalida ; Datos que se escribirán
        mov ecx, bytesEsperados ; Cantidad de bytes a escribir
        call WriteToFile ; Devuelve los bytes escritos en EAX
        jc errorEscritura
        cmp eax, bytesEsperados ; Deben coincidir con los esperados
        jne errorEscritura

        mov eax, archivoHandle
        call CloseFile
        test eax, eax ; Si el resultado es cero el cierre falló
        jz errorGuardar
        mov cambios, 0 ; Ya no hay cambios pendientes
        mov edx, OFFSET msgGuardado
        call WriteString
        jmp finGuardar

    errorEscritura: ;Función cuando falla la escritura
        mov eax, archivoHandle
        call CloseFile ; Se cierra el archivo para no bloquear la memoria

    errorGuardar: ;Función que muestra mensaje de error
        mov edx, OFFSET msgNoGuardado
        call WriteString

    finGuardar:
        pop esi ; Se restauran los valores iniciales
        pop edx
        pop ecx
        pop ebx
        pop eax
        ret
Guardar ENDP

LeerLinea PROC ;Copia a entrada la línea de bufArchivo que empieza en posArchivo
    ;La línea termina con el salto de línea 0Dh 0Ah o con el fin del texto
    ;Entradas: posArchivo con la posición de lectura
    ;Salidas: EAX = 1 si se leyó bien o 0 si la línea es muy larga o está mal terminada,
    ;entrada con la línea y posArchivo avanzado a la siguiente línea
    ;Registros modificados: EAX
    push ebx ; Se guardan los valores iniciales
    push esi

    mov esi, posArchivo ; ESI es el índice dentro de bufArchivo
    mov ebx, 0 ; EBX es el índice de entrada

    cicloLinea:
        mov al, bufArchivo[esi]
        cmp al, 0dh ; Retorno de carro
        je finLineaCR
        cmp al, 0 ; Fin del texto
        je finLineaTexto
        cmp ebx, 30 ; Límite de longitud de una línea
        jae lineaMala
        mov entrada[ebx], al ; Se copia el carácter a entrada
        inc ebx
        inc esi
        jmp cicloLinea

    finLineaCR:
        mov entrada[ebx], 0 ; Se cierra la cadena con 00h
        inc esi ; Salta el retorno de carro
        mov al, bufArchivo[esi]
        cmp al, 0ah ; Después debe venir el salto de línea
        jne lineaMala
        inc esi ; Salta el salto de línea
        mov posArchivo, esi ; La siguiente lectura empieza en la línea que sigue
        mov eax, 1
        jmp finLeerLinea

    finLineaTexto:
        mov entrada[ebx], 0 ; Última línea sin salto de línea al final
        mov posArchivo, esi
        mov eax, 1
        jmp finLeerLinea

    lineaMala:
        mov eax, 0 ; Línea demasiado larga o mal terminada

    finLeerLinea:
        pop esi ; Se restauran los valores iniciales
        pop ebx
        ret
LeerLinea ENDP

ValidarArchivo PROC ;Revisa el texto leído en bufArchivo antes de reemplazar el catálogo
;Cada producto leído se valida y se guarda en la zona temporal de la tabla (desde la posición 440)
    ;Salidas: EAX = 1 si todo el archivo es válido, 0 si no lo es; tmpTotal = total de productos
    ;Registros modificados: EAX
    push ebx ; Se guardan los valores iniciales
    push ecx
    push edx
    push esi

    mov posArchivo, 0 ;se inicializan valores
    mov contados, 0
    mov posTmp, 440 ; El primer registro temporal está en la posición 440

    call LeerLinea ; La primera línea trae el total de productos
    cmp eax, 1
    jne archivoInvalido
    mov ebx, 10 ; El máximo de productos es 10
    call ConvertirEntero
    cmp eax, 1
    jne archivoInvalido
    mov tmpTotal, ecx ; Se guarda el total declarado en el archivo

    revisarProducto:
        mov eax, contados
        cmp eax, tmpTotal ; Se termina cuando ya se leyeron todos los productos
        jae finProductos

        call LeerLinea ; Línea del id
        cmp eax, 1
        jne archivoInvalido
        call ValidarId
        cmp eax, 1
        jne archivoInvalido
        mov esi, 440 ; La búsqueda empieza en la zona temporal
        mov ecx, contados ; Solo se revisan los productos ya leídos
        call BuscarId ; ¿El id está repetido entre los registros temporales anteriores?
        cmp eax, 1
        je archivoInvalido
        mov esi, posTmp
        call CopiarEntrada ; Se guarda el id en el desplazamiento +0

        call LeerLinea ; Línea del nombre
        cmp eax, 1
        jne archivoInvalido
        call ValidarNombre
        cmp eax, 1
        jne archivoInvalido
        mov esi, posTmp
        add esi, 8 ; El nombre va en el desplazamiento +8
        call CopiarEntrada

        call LeerLinea ; Línea del precio
        cmp eax, 1
        jne archivoInvalido
        mov ebx, 999999 ; Precio máximo en centavos
        call ConvertirEntero
        cmp eax, 1
        jne archivoInvalido
        cmp ecx, 1 ; Precio mínimo: 1 centavo
        jb archivoInvalido
        mov esi, posTmp
        mov DWORD PTR tabla[esi+36], ecx ; Precio en el desplazamiento +36

        call LeerLinea ; Línea de la cantidad
        cmp eax, 1
        jne archivoInvalido
        mov ebx, 100 ; Cantidad máxima
        call ConvertirEntero
        cmp eax, 1
        jne archivoInvalido
        mov esi, posTmp
        mov DWORD PTR tabla[esi+40], ecx ; Cantidad en el desplazamiento +40

        add posTmp, 44 ; Siguiente registro temporal
        inc contados ; Un producto más leído
        jmp revisarProducto

    finProductos:
        mov esi, posArchivo
        mov al, bufArchivo[esi]
        cmp al, 0 ; No deben sobrar datos después del último producto
        jne archivoInvalido
        mov eax, 1 ; Archivo válido
        jmp finValidarArchivo

    archivoInvalido:
        mov eax, 0

    finValidarArchivo:
        pop esi ; Se restauran los valores iniciales
        pop edx
        pop ecx
        pop ebx
        ret
ValidarArchivo ENDP

Cargar PROC ;Lee el archivo, valida los datos y solo si son válidos reemplaza el catálogo
    push eax
    push ebx
    push ecx
    push edx
    push esi

    mov edx, OFFSET nombreArchivo
    call OpenInputFile ; Se devuelve el identificador a EAX
    cmp eax, INVALID_HANDLE_VALUE ;se comprueba que no exista error
    jne archivoAbierto
    mov edx, OFFSET msgNoArchivo ; Archivo ausente
    call WriteString
    jmp finCargar

    archivoAbierto:
        mov archivoHandle, eax ; Se guarda el identificador del archivo
        mov eax, archivoHandle
        mov edx, OFFSET bufArchivo ; Buffer donde se guardará el contenido
        mov ecx, SIZEOF bufArchivo-1 ; Capacidad de lectura sin contar el 00h final
        call ReadFromFile ; Devuelve los bytes leídos en EAX
        jc errorLectura ;salta si hay un error de lectura
        mov bytesLeidos, eax
        mov eax, archivoHandle
        call CloseFile
        mov ebx, bytesLeidos
        mov bufArchivo[ebx], 0 ; 00h después del último byte leído
        cmp bytesLeidos, SIZEOF bufArchivo-1
        jae archivoMalo ; Si llenó el buffer el archivo es demasiado grande
        call ValidarArchivo ; Se valida todo el archivo antes de tocar el catálogo
        cmp eax, 1
        je reemplazar

    archivoMalo: ;Función cuando el archivo no es válido
        mov edx, OFFSET msgArchivoMal ; El catálogo actual no se modifica
        call WriteString
        jmp finCargar

    reemplazar:
        mov eax, tmpTotal
        mov totalProd, eax ; El total del archivo pasa a ser el total del catálogo
        mov esi, 0 ; ESI es el índice del byte que se copia
        mov ecx, 440 ; Se copian los 440 bytes del catálogo

    copiar:
        mov al, tabla[esi+440] ; Byte de la zona temporal
        mov tabla[esi], al ; Se escribe en el catálogo
        inc esi
        loop copiar

        mov cambios, 0 ; El catálogo coincide con el archivo
        mov edx, OFFSET msgOk
        call WriteString
        jmp finCargar

    errorLectura: ;Función cuando falla la lectura
        mov eax, archivoHandle
        call CloseFile ; Se cierra el archivo para no bloquear la memoria
        mov edx, OFFSET msgErrLectura
        call WriteString

    finCargar:
        pop esi ; Se restauran los valores iniciales
        pop edx
        pop ecx
        pop ebx
        pop eax
        ret

Cargar ENDP

END main