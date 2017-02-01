const marked = require( 'marked' );
const dateFormat = require( 'dateformat' );

const render = require( '../utils/render' );

const issueMonthOrder = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'Midsummer',
  'August', 'September', 'October', 'November', 'December' ];

const issueOrder = function( issue ) {
  // Issues come in like January 2013
  const parts = issue.split(' ');
  return ( parseInt(parts[1]) * 100 ) + issueMonthOrder.indexOf( parts[0] );
}

const slug = i => i.replace( ' ', '-' );

const issues = newsletters => {
  const prepped = newsletters
    .map( n => n.issue )
    .filter(( v, i, a ) => a.indexOf( v ) === i )
    .sort(( a, b ) => issueOrder( b ) - issueOrder( a ));

  return render( 'newsletters/aside', { issues: prepped, slug } );
}

const renderArticle = article =>
  render( 'newsletters/article', Object.assign( {}, article, {
    body: marked( article.body ),
    standardDate: dateFormat( article.date, "yyyy-mm-dd" ),
    displayDate: dateFormat( article.date, "mmmm d, yyyy" )
  }));

module.exports = function( params, newsletters ) {
  const articleMarkup = newsletters
    .filter( n => slug( n.issue ) === params.issue )
    .sort(( a, b ) => a.order - b.order )
    .map( renderArticle )
    .join('');

  return {
    content: render( 'newsletters/layout', { main: articleMarkup }),
    aside: issues( newsletters )
  };
}
