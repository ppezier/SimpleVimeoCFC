<cfscript>

	/* r�cup�ration de la config de l'API */
	config = deserializeJson(fileRead(expandPath("config.json")));

	/* instantiation du composant */
	vimeo = new vimeo( accessToken=config.access_token);

	/* upload d'une vid�o */
	adresse = vimeo.upload( file_path=expandPath("./test.mpg") , upgrade_to_1080=true );

	/* r�cup�ration des infos et affichage */
	video = vimeo.callAPI(adresse);
	writeOutput(video.uri);

</cfscript>
