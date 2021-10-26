## Determine Cert bound to a specific port


From command prompt:

	netsh http show sslcert


Will show which certificate thumbprint is bound to the port


### SSL Certificate bindings:
---
    
    IP:port : 0.0.0.0:19080	
    Certificate Hash : b24ac3bbf58709de716dbdce4ff31cb5f08aca19	
    Application ID : {7f7f579c-89a9-412e-b4ef-1ac59cdf2f25}	
    Certificate Store Name : My	
    Verify Client Certificate Revocation : Disabled	
    Verify Revocation Using Cached Client Certificate Only : Disabled	
    Usage Check : Enabled	
    Revocation Freshness Time : 0	
    URL Retrieval Timeout : 0	
    Ctl Identifier : (null)	
    Ctl Store Name : (null)	
    DS Mapper Usage : Disabled	
    Negotiate Client Certificate : Disabled	
	
	
	IP:port : 0.0.0.0:9001	
	Certificate Hash : 85fb1cb077cd7c78789f5bb61a7a4f3b282008e3	
	Application ID : {ba9bcb9f-58ac-4f6d-8e53-95f20f6811cd}	
	Certificate Store Name : My	
	Verify Client Certificate Revocation : Disabled	
	Verify Revocation Using Cached Client Certificate Only : Disabled	
	Usage Check : Enabled	
	Revocation Freshness Time : 0	
	URL Retrieval Timeout : 0	
	Ctl Identifier : (null)	
	Ctl Store Name : (null)	
	DS Mapper Usage : Disabled	
	Negotiate Client Certificate : Disabled
