require 'rubygems'
require 'mechanize'
require 'logger'

class Overdue
  attr_reader :checked_out
  
  def initialize(card_number, zip)
    @card_number = card_number
    @zipcode = zip
    @agent = WWW::Mechanize.new do |a|
      a.user_agent_alias = 'Windows IE 6' # lowest common denominator!
      a.log = Logger.new('chipublib.log')
    end
    
    @logged_in = false
    @checked_out = []
  end

  def login
    page = @agent.get('http://www.chipublib.org/mycpl/login/')
      # When finding forms, you can't search by :id because it's reserved!
      login_form = page.form_with(:action => '/mycpl/login/')
      
      login_form.patronId = @card_number
      login_form.zipCode = @zipcode
      
      post_login = @agent.submit(login_form) # return a Mechanize::Page object with the results of the login
      
      # Return whether or not there's a login form. If there's not, it worked.
      # Since we're returning true on success, we need to invert the result before we return it.
      @logged_in = true
      !post_login.form_with(:action => '/mycpl/login/')
  end
  
  def current_page
    @agent.page.uri
  end
  
  def get_checked_out
    # Returns a hash of books checked out along with their due dates
    # Mechanize is based on Nokogiri so it inherits access to Nokogiri functions
    page = Nokogiri::HTML(@agent.get('http://www.chipublib.org/mycpl/summary/').body)
    
    # Find the table containing checked-out books
    books = page.search("table[width='95%']").first.search('tr')
    
    # Shift off the first item with the table header in it
    books.shift
    
    books.each do |book|
      @checked_out.push Hash['title' => book.children[2].content, 'due' => book.children[6].content]
      # title = book.children[2].content
      # due date = book.children[6].content
    end
    
    # Return the array of hashes
    @checked_out    
  end

  def get_holds
    
  end
  
  def due_soon(days)
    # Returns a list of books due in the next x days
    if @checked_out.empty?
      return false
    end
    
    due_soon = []
    
    @checked_out.each do |book|
      due_in = (Date.parse(book['due']) - Date.today).to_i
      
      if due_in < days
        due_soon.push Hash['title' => book['title'], 'due' => book['due'], 'due_in' => due_in]
      end
    end
    
    due_soon  
  end
  
  def get_preferred_library
    page = Nokogiri::HTML(@agent.get('http://www.chipublib.org/mycpl/').body)
    page.css("a[title='Go to my preferred library.']").inner_html.strip
  end
  
  def catalog_search(term, type = 'keyword')
    page = @agent.get('http://www.chipublib.org/search/catalog/')
    search_form = page.form_with(:action => '/search/results/')
    
    search_form.terms = term
    
    results_page = Nokogiri::HTML(search_form.submit.body).search('ol.result li')
    
    results = []
    # title
    # media type
    # author (if any)
    # series
    # published
    # call no.
    # language
    # item_id
    # image
    
    results_page.each do |result|
      results.push Hash
        [ 'title'  =>  result.inner_html,
          'author' => ''
        ]
    end
    
    # Return the results hash
    results
  end
end