/**
 * @author Patrick Pézier - http://patrick.pezier.com
 * Composant ColdFusion communiquant avec l'API Vimeo
 */
component
	accessors="true"
	output="false"
	{

		/* encodage */
		pageencoding "utf-8";

		/* propriétés */
		property name="accessToken" type="string"; // access token fourni par Vimeo

		/* constantes */
		this.API_URL = "https://api.vimeo.com"; // url racine de l'API
		this.API_OEMBED_URL = "https://vimeo.com/api"; // url racine de l'API oEmbed
		this.API_VERSION = "application/vnd.vimeo.*+json; version=3.2"; // version de l'API

		/**
		 * constructeur
		 */
		public vimeo function init( string accessToken="" ){
			this.setAccessToken(arguments.accessToken);
			return(this);
		}


		/**
		 * Appelle l'API
		 * @endPoint.hint  endpoint demandé (utiliser "/oembed.json" pour l'API oEmbed)
		 * @params.hint    struct de paramètres
		 * @method.hint  méthode (GET ou POST)
		 */
		public any function callAPI( string endPoint="", struct params={}, string method="GET" ){

			/* préparation de l'appel à l'API Vimeo */
			var httpService = new http( method="#arguments.method#" );
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

				case "DELETE": case "PATCH": case "PUT": // méthode PATCH non supportée par CF avant la v11 update3
				break;

				default:
					return( "Erreur : Méthode non prise en charge." );
				break;
			} // fin switch

			/* appel de l'API */
			var result = httpService.send().getPrefix(); 

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
			} // fin if

		} // fin function callAPI


		/**
		 * Uploade un fichier
		 * @file_path.hint	string $file_path Path to the video file to upload.
		 * @upgrade_to_1080.hint boolean $upgrade_to_1080 Should we automatically upgrade the video file to 1080p
		 */
		public any function upload( required string file_path, boolean upgrade_to_1080=false ){

			/* vérificaion du quota */
			var me = this.callAPI( endpoint="/me" );
			var quota = val(me.upload_quota.space.free);

			/* pointeur sur le fichier */
			var file_pt = fileOpen( arguments.file_path , "readBinary" );
			if (file_pt.size gt quota)
				return( "Erreur : quota insuffisant (" & (file_pt.size-quota)/1000000 & " Mo manquants)." );

			/* génération d'un ticket d'upload */
			var ticketParams = {
				type = "streaming",
				upgrade_to_1080 = arguments.upgrade_to_1080
			};
			var ticket = this.callAPI( endpoint="/me/videos", params="#ticketParams#", method="POST" ); 
			if (!isDefined("ticket.upload_link_secure"))
				return( "Erreur : ticket invalide." );

			/*
				appel de la fonction d'upload proprement dite
				scope "variables" et non pas "this" car la méthode est en accès "private"
			*/
			return( variables.perform_upload(file_pt,ticket) );
		} // fin function upload


		/**
		 * Reçoit un ticket d'upload et réalise l'upload effectif
		 * @file_pt.hint file obj Pointeur sur le fichier à uploader
		 * @ticket.hint ticket obj Données du ticket d'upload
		 */
		private any function perform_upload( required file_pt, required struct ticket ){

			var chunkSize = 1024*1024*50; // upload par fragments de 50 Mo
			var bitsUploaded = 0;

			/* composant http pour l'upload */
			var httpService = new http( method="PUT" );
			httpService.setUrl( arguments.ticket.upload_link_secure );

			/* boucle do-while d'upload de la vidéo par fragment, avec vérification à chaque envoi */
			do { 

				/* upload (d'une partie) de la vidéo */
				httpService.clearParams();
				httpService.addParam( type="HEADER", name="Content-Type", value="video/#lCase(listLast(arguments.file_pt.name,'.'))#" );
				if (!bitsUploaded){ // si 1er fragment
					httpService.addParam( type="HEADER", name="Content-Length", value="#arguments.file_pt.size#" );
				} else { // si 2e fragment ou +
					httpService.addParam( type="HEADER", name="Content-Length", value="#min(arguments.file_pt.size-bitsUploaded,chunkSize)#" );
					httpService.addParam( type="HEADER", name="Content-Range", value="bytes #bitsUploaded#-#min(bitsUploaded+chunkSize,arguments.file_pt.size)#/#arguments.file_pt.size#");
				} // fin if
				httpService.addParam( type="BODY", value="#fileRead(arguments.file_pt,chunkSize)#" );

				var result = httpService.send().getPrefix(); 
				if ( val(result.statusCode) neq 200 )
					return( "Erreur d'upload : " & result.statusCode );


				/* vérification de l'upload */
				httpService.clearParams();
				httpService.addParam( type="HEADER", name="Content-Length", value="0" );
				httpService.addParam( type="HEADER", name="Content-Range", value="bytes */*" );
				result = httpService.send().getPrefix();

				var bitsUploaded = listLast(result.ResponseHeader.range,"-");

			} // fin do
			while (bitsUploaded lt arguments.file_pt.size); // on boucle tant qu'on n'a pas uploadé toute la vidéo

			/* libération du pointeur */
			fileClose(arguments.file_pt);

			/* finalisation de l'upload */
			var finalisation = this.callAPI( endpoint="#arguments.ticket.complete_uri#", method="DELETE" );
			if ( !isDefined("finalisation.statusCode") or val(finalisation.statusCode)!=201 )
				return( "Erreur lors de la finalisation" );
			else
				return(finalisation.ResponseHeader.Location);

		} // fin function perform_upload


	}
