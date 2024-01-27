# Container based services stop responding after upgrade to Service Fabric 7.1.417.9590

## Symptom

Containers using NAT networking mode may have connectivity issues after upgrading to Service Fabric 7.1.417.9590. Connections fail with a message indicating there are no listeners listening on the specified port.

## Validating if this TSG is the cause for container connectivity

1. Determine the port used on the Host VM for the container by examining URI for one of the instances of the service in SFX – note down the port and Node / VM that instance is running on

2. RDP to the VM identified in previous step

3. Open a powershell prompt as administrator and run the following command

    ```powershell
    netstat -ano
    ```

    Examine output of netstat, check if the port noted down in step1 is present in the list and if it is in LISTENING state

    * If the port is present and status is listening, this TSG does not apply

    * If port is not present continue with this TSG

4. Run the following command to further validate that this TSG applies

    ```powershell
    docker ps
    ```

    * Identify the image / container associated with the failing service.

    * Examine PORTS column that has information similar to below. Ports column can contain multiple mappings separated by comma, examine all of them.

        ```cmd
        0.0.0.0:VM_PORT->SOME_PORT_NUMBER/PROTOCOL

        SOME_PORT_NUMBER corresponds to the port the application is listening on inside the container
        PROTOCOL is usually tcp
        ```

    * If VM_PORT corresponds to port noted down in step 1, then this TSG does not apply
    * If VM_PORT does not correspond to port noted down in step 1, continue

## Cause

A recent change introduced in 7.1 is using case sensitive comparison to match the following

1. Endpoint name specified in Application manifest and the corresponding endpoint name in the service manifest
2. Code package name

When there is a case mismatch for the above names in the manifests, SF does not setup port mapping correctly.

### Example with mismatch – Endpoint name

```xml
<!-- Service Manifest -->
...
<Resources>
    <Endpoints>
        <!-- lower case p used in contosoEndpoint -->
        <Endpoint Name="contosoEndpoint" Protocol="http" UriScheme="http" />
    </Endpoints>
</Resources>
...

<!-- Application Manifest -->
...
<!-- upper case p used in contosoEndPoint -->
<PortBinding ContainerPort="80" EndpointRef="contosoEndPoint" />
...
```

### Example with mismatch - Code package name

```xml
<!-- Service Manifest -->
...
<!-- upper case p used in contocoCodePackage -->
<CodePackage Name="contocoCodePackage" Version="20200607.2">
    <EntryPoint>
        <ContainerHost>
            <ImageName>xyz:latest</ImageName>
        </ContainerHost>
    </EntryPoint>
</CodePackage>
...
<Resources>
    <Endpoints>
        <!-- lower case p used in contocoCodepackage -->
        <Endpoint Name="Endpoint1" Protocol="http" CodePackageRef="contocoCodepackage" UriScheme="http" />
    </Endpoints>
</Resources>
...
```

## Mitigation

Following are options for mitigation

1. Update endpoint names/code package names so they match exactly and upgrade the application
2. Move to the latest available version of Service Fabric 7.0

### Endpoint sample modified to apply Mitigation 1 in application manifest

```xml
<!-- Application Manifest -->
<!-- changed from upper case p  to lower case p in contosoEndpoint -->
<PortBinding ContainerPort="80" EndpointRef="contosoEndpoint" />
```

### CodePackage sample modified to apply Mitigation 1

```xml
<!-- Service Manifest -->
...
<!-- upper case p used in contocoCodePackage -->
<CodePackage Name="contocoCodePackage" Version="20200607.2">
    <EntryPoint>
        <ContainerHost>
            <ImageName>xyz:latest</ImageName>
        </ContainerHost>
    </EntryPoint>
</CodePackage>
...
<Resources>
    <Endpoints>
        <!-- changed from lower case p to upper case p in contocoCodePackage -->
        <Endpoint Name="Endpoint1" Protocol="http" CodePackageRef="contocoCodePackage" UriScheme="http" />
    </Endpoints>
</Resources>
...
```

## Fix

We expect to ship a fix for 7.1 version of SF around the end of July / beginning of August.
