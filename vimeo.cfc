/**
* @author Patrick Pézier - http://patrick.pezier.com
* Composant ColdFusion communiquant avec l'API Vimeo
*/
component
	accessors="true"
	output="false"
	{

		// propriétés
		property name="accessToken" type="string"; // access token fourni par Vimeo

		// constantes
		this.API_URL = "https://api.vimeo.com"; // url racine de l'API
		this.API_OEMBED_URL = "https://vimeo.com/api"; // url racine de l'API oEmbed
		this.API_VERSION = "application/vnd.vimeo.*+json; version=3.2"; // version de l'API

		/**
		* constructeur
		*/
		function init(accessToken=""){
			this.setAccessToken(arguments.accessToken);
			return(this);
		}


		/**
		* Appelle l'API
		* @endPoint.hint  endpoint demandé (utiliser "/oembed.json" pour l'API oEmbed)
		* @params.hint    struct de paramètres
		* @endPoint.method  méthode (seule GET est supportée)
		*/
		function callAPI( endPoint="", params={}, method="GET" ){

			/* préparation de l'appel à l'API Vimeo */
			httpService = new http();
			httpService.setMethod(arguments.method);
			if (!compare(left(arguments.endPoint,7),"/oembed"))
				httpService.setUrl(this.API_OEMBED_URL & endpoint);
			else
				httpService.setUrl(this.API_URL & endpoint);

			/* définition d'une struct pour les headers puis ajout */
			headers = {
				Accept = "application/vnd.vimeo.*+json;version=3.2"
			};
			if (len(this.getAccessToken()))
				structInsert(headers, "Authorization", "bearer "&this.getAccessToken());
			for (key in headers)
				httpService.addParam(type="header", name="#key#", value="#structFind(headers,key)#");

			/* ajout des paramètres en fonction de la méthode */
			switch(uCase(method)){
				case "GET":
					for (key in arguments.params)
						httpService.addParam(type="URL", name="#lCase(key)#", value="#structFind(arguments.params,key)#");
				break;

				default:
					return( "Erreur : Méthode non prise en charge." );
				break;
			}

			/* appel de l'API */
			result = httpService.send().getPrefix(); 

			/* traitement du contenu renvoyé */ 
			if (val(result.statusCode) eq 200) {
				if (isJSON(result.fileContent))
					return( deserializeJSON(result.fileContent) );
				else if (isXML(result.fileContent))
					return( xmlParse(result.fileContent) );
				else
					return( "Erreur : Mauvais format retourné par l'API" );
			} else {
				return( "Erreur : " & result.statusCode );	
			}

		}

	}
