// docs/javascripts/loader.js

// Wir erstellen dynamisch ein Script-Tag
const script = document.createElement('script');

// Wir weisen den Browser an, es als Modul zu behandeln
script.type = 'module';

// Der Pfad zu deiner eigentlichen Shiki-Logik
script.src = '/javascripts/shiki_init.js'; 

// Wir hängen das Script in den Head der Seite
document.head.appendChild(script);