<cfscript>

  /* récupération de la config de l'API */
  config = deserializeJson(fileRead(expandPath("config.json")));

  /* Instantiation */
  vimeo = new vimeo( accessToken=config.access_token );

  /* Récup des vidéos */
  videos = vimeo.callAPI("/me/videos");
  writeDump(videos);

</cfscript>