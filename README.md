# Microproyecto 1 - Computación en la Nube

Balanceo de carga con HAProxy y descubrimiento dinámico de servicios con Consul, sobre tres máquinas virtuales administradas con Vagrant. Este proyecto fue desarrollado para el curso de Computación en la Nube de la UAO.

## Descripción

El ambiente está compuesto por tres máquinas virtuales Ubuntu 22.04. Las máquinas web1 y web2 corren la aplicación (dos réplicas de Node.js cada una, en los puertos 3000 y 3001) y un agente de Consul, uno como servidor y el otro como cliente. La máquina lb corre HAProxy y consul-template, que consulta a Consul constantemente para saber qué servidores están disponibles y regenera la configuración de HAProxy automáticamente, sin que las IPs de los backends estén escritas a mano.

## Requisitos previos

Se necesita tener instalados Vagrant y VirtualBox. En Windows, si tienen Hyper-V activo (por ejemplo por usar WSL2 o Docker Desktop), es necesario desactivarlo antes de levantar las máquinas, porque puede hacer que el arranque se cuelgue o sea muy lento. Se desactiva así, desde PowerShell como administrador, y requiere reiniciar el equipo:

```
bcdedit /set hypervisorlaunchtype off
```

## Cómo levantar el ambiente

Clonar el repositorio y entrar a la carpeta:

```
git clone https://github.com/DarkKnight1003-cyber/Microproyecto1Compunube.git
cd Microproyecto1Compunube
```

Levantar las tres máquinas (puede tardar varios minutos la primera vez, porque instala Node, Consul, HAProxy y consul-template):

```
vagrant up
```

## Cómo verificar que funciona

La aplicación balanceada queda disponible en:

```
http://192.168.56.13
```

Al recargar varias veces se puede ver cómo va cambiando el servidor y el puerto que responde. Las estadísticas de HAProxy, con el estado de cada backend, quedan disponibles en:

```
http://192.168.56.13:1936
```

## Pruebas de carga

Las pruebas se hacen con Artillery, desde el equipo anfitrión (no dentro de las máquinas virtuales). Primero se instalan las dependencias:

```
npm install
```

Y luego se corre cada escenario:

```
npx artillery run artillery/carga-baja.yml
npx artillery run artillery/carga-media.yml
npx artillery run artillery/carga-alta.yml
```
## Mensaje personalizado de servicio no disponible

El balanceador de carga HAProxy cuenta con una página de error personalizada para los casos en los que no existen servidores web disponibles.

Cuando los servidores `web1` y `web2` dejan de responder o no superan las verificaciones de salud, HAProxy detecta que no existen backends disponibles y devuelve automáticamente un error HTTP `503 Service Unavailable`.

En lugar de mostrar el mensaje predeterminado de HAProxy, el sistema presenta un aviso personalizado al usuario indicando que el servicio se encuentra temporalmente no disponible y que debe intentar nuevamente después de unos minutos.

El mensaje mostrado es el siguiente:

**Servicio temporalmente no disponible**

En este momento no hay servidores web disponibles.

Por favor, intente nuevamente en unos minutos.

Esta página está configurada en el balanceador mediante el archivo:

`/etc/haproxy/errors/503.http`

## Integrantes

- Juan Esteban Aristizabal
- Juan Felipe Lopez
- John Angel Posso
