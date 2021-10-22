## Why do cluster upgrades take so long

Cluster upgrade performance questions come up somewhat frequently, I hope the following helps explain in some detail how the Service Fabric cluster upgrade process works and what effect it has on the end-to-end performance. 


The default settings can be found in the Advanced Upgrade settings for the cluster.  Azure Portal -> Resource group -> Service Fabric Cluster -> Fabric Upgrades (check Advanced Settings)

 
	Service Fabric handles cluster wide settings changes such as Security changes, Placement Settings, custom fabric settings, etc as a cluster upgrade and as such it will trigger a two phase full UD (Upgrade Domain) walk to apply these changes to the cluster one upgrade domain at a time.  After the changes are applied it will wait for some period of time based on the configured health and stability settings to ensure the change does not cause your cluster to destabilize. 


	By default the Health Check policy are assigned the following settings, which will translate to ~26 minutes to walk each UD as there are two phases to apply the change for each UD, so calculation would be ((wait + stable + 3 min runtime upgrade)*2) = total time per UD, + if any errors are detected it will wait 45 (default health_check_retry_timeout) minutes before retrying again.  You can change the health check wait and stable duration times to make the operations complete faster in Advanced Upgrade settings, but it’s a tradeoff between speed and safety as SF will monitor the upgrade and attempt to rollback if the changes cause any errors to occur.  These defaults are pretty conservative, but we do not recommend lowering these duration below 30 seconds.  If you have many stateful services deployed keep in mind that partitions are failing over from the node being updated to another node still running and it can take some time for reconfiguration to take place and have the replicas back up and running, so changing the duration to a very short timespan could potentially allow deployment of a breaking change which would not manifest any errors until the upgrade already advanced to the next UD.

| Setting | Description |
|---|---|
| health_check_retry_timeout | The length of time between attempts to perform a health checks if the application or cluster is not healthy. Default value: "PT0H0M0S". |
| health_check_wait_duration_in_seconds | The length of time to wait after completing an upgrade domain before starting the health checks process. Default value: "PT0H0M0S". |
| health_check_stable_duration_in_seconds | The length of time that the application or cluster must remain healthy. Default value: "PT0H0M0S". |


## More info here:

[https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-upgrade#fabric-upgrade-settings---health-polices](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-upgrade#fabric-upgrade-settings---health-polices "Fabric Upgrade Settings")

[https://docs.microsoft.com/en-us/rest/api/servicefabric/sfclient-v62-model-clusterconfigurationupgradedescription](https://docs.microsoft.com/en-us/rest/api/servicefabric/sfclient-v62-model-clusterconfigurationupgradedescription "ClusterConfigurationUpgradeDescription")

