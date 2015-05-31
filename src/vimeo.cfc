/**
* @author Patrick Pézier - http://patrick.pezier.com
* Composant ColdFusion communiquant avec l'API Vimeo
*/
component
	accessors="true"
	output="false"
	{

		// encodage
		pageencoding "utf-8";

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
		* @method.hint  méthode (GET ou POST)
		*/
		function callAPI( endPoint="", params={}, method="GET" ){

			/* préparation de l'appel à l'API Vimeo */
			httpService = new http( method="#arguments.method#" );
			if (!compareNoCase(left(arguments.endPoint,7),"/oembed"))
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
				httpService.addParam(type="HEADER", name="#key#", value="#structFind(headers,key)#");

			/* ajout des paramètres en fonction de la méthode */
			switch(uCase(method)){
				
				case "GET":
					for (key in arguments.params)
						httpService.addParam(type="URL", name="#lCase(key)#", value="#structFind(arguments.params,key)#");
				break;

				case "POST":
					for (key in arguments.params)
						httpService.addParam(type="FORMFIELD", name="#lCase(key)#", value="#structFind(arguments.params,key)#");
				break;

				case "DELETE": case "PATCH": case "PUT":
				break;

				default:
					return( "Erreur : Méthode non prise en charge." );
				break;
			}

			/* appel de l'API */
			result = httpService.send().getPrefix(); 

			/**
			* traitement du contenu renvoyé
			*	200 = OK		= Requête traitée avec succès
			*	201 = Created	= Requête traitée avec succès avec création d’un document
			*/
			if (listFind( "200,201", val(result.statusCode) )) {
				if (isJSON(result.fileContent))
					/* retour de type Json */
					return( deserializeJSON(result.fileContent) );
				else if (isXML(result.fileContent))
					/* retour de type XML */
					return( xmlParse(result.fileContent) );
				else
					return( result );
			} else {
				return( "Erreur : " & result.statusCode );	
			}

		}


		/**
		* Uploade un fichier
		* @file_path.hint	string $file_path Path to the video file to upload.
		* @upgrade_to_1080.hint boolean $upgrade_to_1080 Should we automatically upgrade the video file to 1080p
		*/
		function upload( file_path, upgrade_to_1080=false ){

			/* vérificaion du quota */
			me = this.callAPI( endpoint="/me" );
			quota = val(me.upload_quota.space.free);

			/* pointeur sur le fichier */
			file_pt = fileOpen( arguments.file_path , "readBinary" );
			if (file_pt.size gt quota)
				return( "Erreur : quota insuffisant (" & (file_pt.size-quota)/1000000 & " Mo manquants)." );

			/* génération d'un ticket d'upload */
			ticketParams =   {
		        type = "streaming",
		        upgrade_to_1080 = arguments.upgrade_to_1080
		    };
			ticket = this.callAPI( endpoint="/me/videos", params="#ticketParams#", method="POST" ); 

			/* appel de la fonction d'upload proprement dite */
			return( this.perform_upload(file_pt,ticket) );
		}


		/**
		* Reçoit un ticket d'upload et réalise l'upload effectif
		* @file_pt.hint file obj Pointeur sur le fichier à uploader
		* @ticket.hint ticket obj Données du ticket d'upload
		*/
		function perform_upload( file_pt, ticket ){

			/* upload de la vidéo */
			httpService = new http( method="PUT" );
			httpService.setUrl( arguments.ticket.upload_link_secure );
			httpService.addParam( type="HEADER", name="Content-Length", value="#arguments.file_pt.size#" );
			httpService.addParam( type="HEADER", name="Content-Type", value="video/#lCase(listLast(arguments.file_pt.name,'.'))#" );
			httpService.addParam( type="BODY", value="#fileRead(arguments.file_pt,arguments.file_pt.size)#" );
			result = httpService.send().getPrefix(); 
			if ( val(result.statusCode) neq 200 )
				return( "Erreur d'upload : " & result.statusCode );

			/* vérification de l'upload */
			httpService.clearParams();
			httpService.addParam( type="HEADER", name="Content-Length", value="0" );
			httpService.addParam( type="HEADER", name="Content-Range", value="bytes */*" );
			result = httpService.send().getPrefix();
			bitsUploaded = listLast(result.ResponseHeader.range,"-");

			/* s'il en manque */
			if ( bitsUploaded lt arguments.file_pt.size){
				/*
					ICI AJOUTER GESTION D'UPLOAD INCOMPLET
				*/				
			}

			/* libération du pointeur */
			fileClose(arguments.file_pt);

			/* finalisation de l'upload */
			finalisation = this.callAPI( endpoint="#arguments.ticket.complete_uri#", method="DELETE" );
			if ( val(finalisation.statusCode) neq 201 )
				return( "Erreur lors de la finalisation : " & finalisation.statusCode );
			else
				return(finalisation.ResponseHeader.Location);

		}


	}
