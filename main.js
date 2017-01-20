var marked = require('marked')

const articleTemplate = a => `
<article>
<h1>${ a.title }</h1>
<span class="author">${ a.author }</span>
${ marked( a.body ) }
</article>`

window.newsletterDisplayer = function ( newsletters ) {
  function issueSort( a, b ) {}

  function getIssues() {
    return newsletters
      .map( n => n.issue )
      .filter(( v, i, a ) => a.indexOf( v ) === i )
  }

  function issueArticles( issue ) {
    return newsletters
      .filter( n => n.issue === issue )
      .sort(( a, b ) => a.order > b.order )
  }


  function displayIssueList( container, issues ) {
    const navMarkup = issues
      .map( i => `<div data-issue="${ i }">${ i }</div>`)
      .join('');

    container.innerHTML = navMarkup;
  }


  function displayIssue( issue ) {
    const main = document.querySelector( 'main' );
    const articleMarkup = issueArticles( issue )
      .map( articleTemplate )
      .join('')

    main.innerHTML = articleMarkup;
  }


  const nav = document.querySelector( 'nav' );
  nav.addEventListener( 'click', function( e ) {
    displayIssue( e.target.dataset.issue );
  });

  displayIssueList( nav, getIssues() );



};
