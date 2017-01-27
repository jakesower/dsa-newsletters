var path = require( 'path' );
var express = require( 'express' );
var app = express();
var serveStatic = require( 'serve-static' );

app.use( serveStatic( path.join( __dirname, '..', 'public' )));

app.listen( 3000, function() {
  console.log( 'Listening on port 3000' );
});
