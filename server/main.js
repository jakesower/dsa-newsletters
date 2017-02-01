var path = require( 'path' )
  , fs = require( 'fs' )

  , express = require( 'express' )
  , app = express()
  , serveStatic = require( 'serve-static' )

  , newsletterData = JSON.parse( fs.readFileSync( __dirname + '/../data/data.json', { encoding: 'utf-8' }))
  , render = require( './utils/render' )

  , NewsletterController = require( './controllers/newsletter_controller' );


app.get( '/newsletters/:issue', ( req, res ) => {
  const parts = NewsletterController( req.params, newsletterData );
  const view = render( 'layout', parts );

  res.send( view );
});

app.get( '/newsletters', ( req, res ) => {
  const parts = NewsletterController( { issue: null }, newsletterData );
  const view = render( 'layout', parts );

  res.send( view );
});


// app.use( serveStatic( path.join( __dirname, '..', 'assets' )));
app.use( '/assets', express.static( __dirname + '/../assets' ));

app.listen( 3000, function() {
  console.log( 'Listening on port 3000' );
});
