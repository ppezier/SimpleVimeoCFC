<cfscript>
  
  /**
  * Access token Vimeo à renseigner dans le config.json
  * à récupérer sur : https://developer.vimeo.com/apps 
  */

  /* récupération de la config de l'API */
  config = deserializeJson(fileRead(expandPath("config.json")));

  /* Instantiation */
  vimeo = new vimeo( accessToken=config.accessToken );

  /* Récup des vidéos */
  videos = vimeo.callAPI("/me/videos");
  writeDump(videos);

</cfscript>
