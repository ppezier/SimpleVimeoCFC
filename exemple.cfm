<cfscript>
  
  /**
  * Access token Vimeo à renseigner
  * à récupérer sur : https://developer.vimeo.com/apps 
  */
  accessToken = "";

  /* Instantiation */
  vimeo = new vimeo( accessToken = accessToken);

  /* Récup des vidéos */
  videos = vimeo.callAPI("/me/videos");
  writeDump(videos);

</cfscript>
