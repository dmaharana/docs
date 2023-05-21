## Oauth configuration
### This article describes using Oauth1 and Oauth2 to authenticate an incoming client and provide tokens (access and refresh) to be used by the client for making further REST API calls. Using Oauth2 is very secure by design as the access token is short lived and has to be regenerated after the expiry. Oauth2 client implementation is simpler to manage as no key file has to be maintained on the client. Oauth2 lets the implementation to be done only through http calls and does not involve decrypting the private key file.

## Oauth 1.0
	- requires to create a pair of private and public keys
	- the client has to use the public key to interact with the server where the application is registered with the private key
	- initial configuration (example from Jira Oauth1.0 configuration to authenticate application - https://developer.atlassian.com/server/jira/platform/oauth/)

    	- Generate a 1024-bit private key:
			- `openssl genrsa -out jira_privatekey.pem 1024`
    	- Create an X509 certificate:
			- `openssl req -newkey rsa:1024 -x509 -key jira_privatekey.pem -out jira_publickey.cer -days 365`
    	- Extract the private key (PKCS8 format) to the jira_privatekey.pcks8 file:
			- `openssl pkcs8 -topk8 -nocrypt -in jira_privatekey.pem -out jira_privatekey.pcks8`
	    - Extract the public key from the certificate to the jira_publickey.pem file:
			- `openssl x509 -pubkey -noout -in jira_publickey.cer  > jira_publickey.pem`
	- Generate application on the server
		- provide the following details
			- Consumer key
			- Public key
			- Shared secret
			- Request token URL
			- Access token URL
			- Authorize URL
		- Configure client
			- Consumer key
			- Private key
		- Authorize the client
			- Client requests with unathorized client key and private key to generate a token and token secret
			- When the first call is made to the server, the user will be presented with a screen to approve the client
			- On approving the client, server will generate a verification code
			- now to generate a access token client has to make a call with consumer key, request token, verification code, and private key
		- Client makes REST API calls to access the server resources with the access token in the authorization header as bearer token
			- the access token has a validity of 5 years on Jira, so the access token has to be regenerated with the above process inorder to ensure token is not compromised

			You can now make requests to the API with the access token returned.
			The access token allows you to make requests to the API on behalf of a user. You can put the token in the Authorization header:

			`curl --header "Authorization: Bearer OAUTH2-TOKEN" "https://atlassian.example.com/rest/api/latest/issue/JRA-9"`

## Oauth 2.0

    - Direct the user to the authorization URL to get an authorization code
    - Exchange the authorization code for an access token
    - Authorize any calls to the product APIs using the access token
    - Check site access for the app
    - Example from Jira Oauth2.0 configuration (https://confluence.atlassian.com/adminjiraserver/jira-oauth-2-0-provider-api-1115659070.html)

    - Authorization code with Proof Key for Code Exchange (PKCE)
		- Create client configuration on the server with
			- client id and client secret
			- Callback (redirect) URL - this is the URL where the server will redirect while generating the authorization code
				- this URL could be the client application end point which could capture the code and automate the generation of bearer token and refresh token
		- use the client id and validators to generate a code from the server
		- use the client id, client secret and the code to generate first pair of bearer token and refresh token
		- from now on use the refresh token to generate a new pair of bearer token and refresh token
	    
	    - Parameters used in the flow
			- redirect_uri	- URL the user is redirected to after authorizing the request.
			- client_id	- Client ID received from Jira after registering your application.
			- response_time - Authorization code.
			- scope	- Scopes that define application’s permissions to the user account. For more info, see Scopes (https://confluence.atlassian.com/adminjiraserver/jira-oauth-2-0-provider-api-1115659070.html#JiraOAuth2.0providerAPI-scopes)
				- READ, WRITE, ADMIN, SYSTEM_ADMIN
			- code_challenge 
				- For sha256, generate this using the following pseudocode: BASE64URL-ENCODE(SHA256(ASCII(code_verifier)))
	    		- For plain, this can be the generated code_verifier.
			- code_challenge_method	- Can be plain or sha256 depending on how the code_challenge was generated.	Yes
			- code_verifier	- High-entropy cryptographic random STRING using the unreserved characters: [A-Z] / [a-z] / [0-9] / "-" / "." / "_" / "~". It must be between 43-127 characters. For more info, see the RFC (https://datatracker.ietf.org/doc/html/rfc7636#section-4.1).

		Note: strings in uppercase are variables to be substituted with actual value

		Steps
		1. Request authorization code by redirecting the user to the /rest/oauth2/latest/authorize page with the following query parameters:
			
			`curl https://atlassian.example.com/rest/oauth2/latest/authorize?client_id=CLIENT_ID&redirect_uri=REDIRECT_URI&response_type=code&state=STATE&scope=SCOPE&code_challenge=CODE_CHALLENGE&code_challenge_method=S256`

			This is the consent screen that asks the user to approve the application’s request to access their account with the scopes specified in scope. The user is then redirected to the URL specified in redirect_uri. The redirect includes the authorization code, like in the following example:

			`https://atlassian.example.com/plugins/servlet/oauth2/consent?client_id=CLIENT_ID&redirect`

		2. With the authorization code returned from the previous request, you can request an access_token, with any HTTP client. The following example uses curl:

			`curl -X POST https://atlassian.example.com/rest/oauth2/latest/token?client_id=CLIENT_ID&client_secret=CLIENT_SECRET&code=CODE&grant_type=authorization_code&redirect_uri=REDIRECT_URI&code_verifier=CODE_VERIFIER`

			Example response

			`{
			 "access_token": "eyJhbGciOiJIUzI1NiJ9.eyJpZCI6IjNmMTQ3NTUzYjg3OTQ2Y2FhMWJhYWJkZWQ0MzgwYTM4In0.EDnpBl0hd1BQzIRP--xEvyW1F6gDuiFranQCvi98b2c",
			 "token_type": "bearer",
			 "expires_in": 7200,
			 "refresh_token": "eyJhbGciOiJIUzI1NiJ9.eyJpZCI6ImMwZTMxYmZjYTI2NWI0YTkwMzBiOGM2OTJjNWIyMTYwIn0.grHOsso3B3kaSxNd0QJfj1H3ayjRUuA75SiEt0usmiM",
			 "created_at": 1607635748
			}`

		3. To retrieve a new access_token, use the refresh_token parameter. Refresh tokens may be used even after the access_token itself expires. The following request:

			    - Invalidates the existing access_token and refresh_token.
			    - Sends new tokens in the response

			`curl -X POST https://atlassian.example.com/rest/oauth2/latest/token?client_id=CLIENT_ID&client_secret=CLIENT_SECRET&refresh_token=REFRESH_TOKEN&grant_type=refresh_token&redirect_uri=REDIRECT_URI`

			Example response

			`{
			  "access_token": "eyJhbGciOiJIUzI1NiJ9.eyJpZCI6ImJmZjg4MzU5YTVkNGUyZmQ3ZmYwOTEwOGIxNjg4MDA0In0.BocpI91mpUzWskyjxHp57hnyl8ZcHehGJwmaBsGJEMg",
			  "token_type": "bearer",
			  "expires_in": 7200,
			  "refresh_token": "eyJhbGciOiJIUzI1NiJ9.eyJpZCI6Ijg1NjQ1YjA1NGJiYmZkNjVmMDNkMzliYzM0YzQ4MzZjIn0.4MSMIG46zjB9QCV-qCCglgojM5dL7_E2kcqmiV46YQ4",
			  "created_at": 1628711391
			}`

	- Authorization code (with out requiring code_challenge)
	Steps

		1. Request the authorization code by redirecting the user to the /oauth/authorize page with the following query parameters:

			`curl https://atlassian.example.com/rest/oauth2/latest/authorize?client_id=CLIENT_ID&redirect_uri=REDIRECT_URI&response_type=code&state=STATE&scope=SCOPE`

			This is the consent screen that asks the user to approve the application’s request to access their account with the scopes specified in scope. The user is then redirected to the URL specified in redirect_uri. The redirect includes the authorization code, like in the following example:

			`https://atlassian.example.com/plugins/servlet/oauth2/consent?client_id=CLIENT_ID&redirect_uri=REDIRECT_URI&response_type=code&scope=SCOPE&state=STATE`

		2. With the authorization code (response_type) returned from the previous request, you can request an access_token, with any HTTP client. The following example uses Ruby’s rest-client:

			`curl -X POST https://atlassian.example.com/rest/oauth2/latest/token?client_id=CLIENT_ID&client_secret=CLIENT_SECRET&code=CODE&grant_type=authorization_code&redirect_uri=REDIRECT_URI`

			Example response

			`{
			 "access_token": "eyJhbGciOiJIUzI1NiJ9.eyJpZCI6IjNmMTQ3NTUzYjg3OTQ2Y2FhMWJhYWJkZWQ0MzgwYTM4In0.EDnpBl0hd1BQzIRP--xEvyW1F6gDuiFranQCvi98b2c",
			 "token_type": "bearer",
			 "expires_in": 7200,
			 "refresh_token": "eyJhbGciOiJIUzI1NiJ9.eyJpZCI6ImMwZTMxYmZjYTI2NWI0YTkwMzBiOGM2OTJjNWIyMTYwIn0.grHOsso3B3kaSxNd0QJfj1H3ayjRUuA75SiEt0usmiM",
			 "created_at": 1607635748
			}`

		3. To retrieve a new access_token, use the refresh_token parameter. Refresh tokens may be used even after the access_token itself expires. This request:

		    - Invalidates the existing access_token and refresh_token.
			- Sends new tokens in the response.

			`curl -X POST https://atlassian.example.com/rest/oauth2/latest/token?client_id=CLIENT_ID&client_secret=CLIENT_SECRET&refresh_token=REFRESH_TOKEN&grant_type=refresh_token&redirect_uri=REDIRECT_URI`

			Example response

			`{
			  "access_token": "eyJhbGciOiJIUzI1NiJ9.eyJpZCI6ImJmZjg4MzU5YTVkNGUyZmQ3ZmYwOTEwOGIxNjg4MDA0In0.BocpI91mpUzWskyjxHp57hnyl8ZcHehGJwmaBsGJEMg",
			  "token_type": "bearer",
			  "expires_in": 7200,
			  "refresh_token": "eyJhbGciOiJIUzI1NiJ9.eyJpZCI6Ijg1NjQ1YjA1NGJiYmZkNjVmMDNkMzliYzM0YzQ4MzZjIn0.4MSMIG46zjB9QCV-qCCglgojM5dL7_E2kcqmiV46YQ4",
			  "created_at": 1628711391
			}`

			You can now make requests to the API with the access token returned.
			The access token allows you to make requests to the API on behalf of a user. You can put the token in the Authorization header:

			`curl --header "Authorization: Bearer OAUTH2-TOKEN" "https://atlassian.example.com/rest/api/latest/issue/JRA-9"`

