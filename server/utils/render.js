var ejs = require( 'ejs' )
  , fs = require( 'fs' )

module.exports = function render( viewPath, data ) {
  const template = fs.readFileSync( __dirname + '/../views/' + viewPath + '.ejs', { encoding: 'utf-8' });

  return ejs.render( template, data );
}
