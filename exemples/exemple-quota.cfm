<cfscript>

	/* récupération de la config de l'API */
	config = deserializeJson(fileRead(expandPath("config.json")));

	/* instantiation du composant */
	vimeo = new vimeo( accessToken=config.accessToken );

	/* infos perso */
	me = vimeo.callAPI( endpoint="/me" );
	writeOutput(me.upload_quota.space.free);

</cfscript>
