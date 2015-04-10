/**
* @author Patrick Pézier - http://patrick.pezier.com
* Composant ColdFusion appelant l'API Vimeo
*/
component
  accessors="true"
  output="false"
  {

  // propriétés
  property name="accessToken" type="string"; // access token fourni par Vimeo

  // constantes
  this.API_URL = "https://api.vimeo.com"; // url racine de l'API
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
  * @endPoint.hint  endpoint demandé
  * @params.hint    struct de paramètres
  * @endPoint.method  méthode (seule GET est supportée)
  */
  function callAPI( endPoint="", params={}, method="GET" ){

    headers = {
      Accept = "application/vnd.vimeo.*+json;version=3.2"
    };
    if (len(this.getAccessToken()))
      structInsert(headers, "Authorization", "bearer "&this.getAccessToken());

    /* préparation de l'appel à l'API Vimeo */
    httpService = new http();
    httpService.setMethod(arguments.method);
    httpService.setUrl(this.API_URL & endpoint);
    for (key in headers)
      httpService.addParam(type="header",name="#key#",value="#structFind(headers,key)#");

    /* paramètres */
    switch(uCase(method)){
      case "GET":
        for (key in arguments.params)
        httpService.addParam(type="url",name="#key#",value="#structFind(arguments.params,key)#");
      break;

      default:
        return( "Erreur : Méhode non prise en charge." );
      break;
    }

    /* appel de l'API */
    result = httpService.send().getPrefix(); 

    /* traitement du contenu renvoyé */ 
    if (val(result.statusCode) eq 200) {
      if (isJSON(result.fileContent))
        return( deserializeJSON(result.fileContent) );
      else
        return( "Erreur : Mauvais format retourné par l'API" );
    } else {
      return( "Erreur : " & result.statusCode );
    }

  }

}
