# Determine Process Listening on Port

RDP to the VMMS instance (Node) and run the following from a cmd prompt:

```command
netsh http show servicestate view=requestq
```

## Example showing

- WebAPI1.exe listening on port 8871
- WebAPI2.exe listening on port 80
- FabricGateway.exe listening on port 19080

```command
C:\\Users\\kwillRDP\>netsh http show servicestate view=requestq

Snapshot of HTTP service state (Request Queue View):
\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\--
Request queue name: Request queue is unnamed.
    Version: 1.0
    State: Active
    Request queue 503 verbosity level: Basic
    Max requests: 1000
    Number of active processes attached: 1
    Process IDs:
        944
    URL groups:
    URL group ID: FE00000040000001
        State: Active
        Request queue name: Request queue is unnamed.
        Properties: 
            Max bandwidth: inherited
            Max connections: inherited
            Timeouts:
                Timeout values inherited
            Number of registered URLs: 2
            Registered URLs:
                <HTTP://+:5985/WSMAN/>
                <HTTP://+:47001/WSMAN/>
        Server session ID: FF00000020000001
            Version: 1.0
            State: Active
            Properties:
                Max bandwidth: 4294967295
                Timeouts:
                    Entity body timeout (secs): 120
                    Drain entity body timeout (secs): 120
                    Request queue timeout (secs): 120
                    Idle connection timeout (secs): 120
                    Header wait timeout (secs): 120
                    Minimum send rate (bytes/sec): 150
    Request queue name: Request queue is unnamed.
        Version: 2.0
        State: Active
        Request queue 503 verbosity level: Basic
        Max requests: 1000
        Number of active processes attached: 1
        Process IDs:
            1344
        URL groups:
        URL group ID: FA00000040000001
            State: Active
            Request queue name: Request queue is unnamed.
            Properties:
                Max bandwidth: inherited
                Max connections: inherited
                Timeouts:
                    Timeout values inherited
                Number of registered URLs: 1
                Registered URLs:
                    <HTTP://+:8871/>
            Server session ID: FB00000020000001
                Version: 2.0
                State: Active
                Properties:
                    Max bandwidth: 4294967295
                    Timeouts:
                        Entity body timeout (secs): 120
                        Drain entity body timeout (secs): 120
                        Request queue timeout (secs): 120
                        Idle connection timeout (secs): 120
                        Header wait timeout (secs): 120
                        Minimum send rate (bytes/sec): 150
    Request queue name: Request queue is unnamed.
        Version: 2.0
        State: Active
        Request queue 503 verbosity level: Basic
        Max requests: 1000
        Number of active processes attached: 1
        Process IDs:
            1552
        URL groups:
        URL group ID: F800000040000001
            State: Active
            Request queue name: Request queue is unnamed.
            Properties:
                Max bandwidth: inherited
                Max connections: inherited
                Timeouts:
                    Timeout values inherited
                Number of registered URLs: 1
                Registered URLs:
                    <HTTP://+:80/>
            Server session ID: F900000020000001
                Version: 2.0
                State: Active
                Properties:
                    Max bandwidth: 4294967295
                    Timeouts:
                        Entity body timeout (secs): 120
                        Drain entity body timeout (secs): 120
                        Request queue timeout (secs): 120
                        Idle connection timeout (secs): 120
                        Header wait timeout (secs): 120
                        Minimum send rate (bytes/sec): 150
    Request queue name: Request queue is unnamed.
        Version: 2.0
        State: Active
        Request queue 503 verbosity level: Basic
        Max requests: 1000
        Number of active processes attached: 1
        Process IDs:
            4364
        URL groups:
        URL group ID: F400000040001D2D
            State: Active
            Request queue name: Request queue is unnamed.
            Properties:
                Max bandwidth: inherited
                Max connections: inherited
                Timeouts:
                    Timeout values inherited
                Number of registered URLs: 1
                Registered URLs:
                    <HTTP://+:19080/>
            Server session ID: F60000002000319F
                Version: 2.0
                State: Active
                Properties:
                    Max bandwidth: 4294967295
                    Timeouts:
                        Entity body timeout (secs): 120
                        Drain entity body timeout (secs): 120
                        Request queue timeout (secs): 120
                        Idle connection timeout (secs): 120
                        Header wait timeout (secs): 120
                        Minimum send rate (bytes/sec): 150


C:\\Users\\kwillRDP\>tasklist /FI \"PID eq 1344\"

Image Name PID Session Name Session\# Mem Usage
========================= ======== ================ =========== ============
WebApi1.exe 1344 Services 0 53,684 K

C:\\Users\\kwillRDP\>tasklist /FI \"PID eq 1552\"

Image Name PID Session Name Session\# Mem Usage
========================= ======== ================ =========== ============
WebApi2.exe 1552 Services 0 53,844 K

C:\\Users\\kwillRDP\>tasklist /FI \"PID eq 4364\"

Image Name PID Session Name Session\# Mem Usage
========================= ======== ================ =========== ============
FabricGateway.exe 4364 Services 0 15,384 K
