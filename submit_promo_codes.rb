require "httparty"

class PromoCodeSubmitter
	include HTTParty
	base_uri "http://concertinauguralsonar.estrelladamm.com/"
	
	# Uncomment the line below to see the HTTP messages
	#debug_output
	
	# Non-HTTParty info
	INITIAL_REQUEST_URI_PATH = "/home"
	SUBMIT_URI_PATH = "/validate"
	LOGIN_URI_PATH = "/loginCheck"
	
	SESSION_ID_COOKIE_PARAMETER = "JSESSIONID"
	INCORRECT_LOGIN_MESSAGE = "LOGIN O PASSWORD INCORRECTE"
	
	def initialize
		@page_parser = ContestPageParser.new
	end
	
	def	log_in_user(username, password)
		session_id = get_session_id_with_initial_request()

		log_in_response = self.class.post(
			LOGIN_URI_PATH,
			:body => {
				:email => username,
				:password => password
			},
			:headers => {"Cookie" => create_cookie_with_session_id(session_id)}
		)
		
		was_login_successful = did_log_in_succeed?(log_in_response.body)
		
		UserLoginResult.new(username, session_id, was_login_successful)
	end
	
	# Makes an initial get request to the website to get a session id
	# This is necessary so we can provide the session id when logging in
	def get_session_id_with_initial_request
		initial_response = self.class.get(
			INITIAL_REQUEST_URI_PATH
		)

		get_session_id_from_cookie(initial_response.headers["set-cookie"])
	end
	
	def get_session_id_from_cookie(cookie_header)
		# Cookie format is JSESSIONID=DEADBEEFDEADBEEFDEADBEEFDEADBE; Path=/; HttpOnly
	
		session_id_param = cookie_header
			.split(';')
			.select{|p| p.index(SESSION_ID_COOKIE_PARAMETER) == 0}.first # Get the cookie param that has the session
		
		# First element is param name, second is session id
		session_id_param.split('=')[1]
	end
	
	def create_cookie_with_session_id(session_id)
		"#{SESSION_ID_COOKIE_PARAMETER}=#{session_id}"
	end
	
	def did_log_in_succeed?(response_body)
		!response_body.index(INCORRECT_LOGIN_MESSAGE)
	end
	
	def	submit_promo_code(user_login_result, promo_code)
		submit_response = self.class.post(
			SUBMIT_URI_PATH,
			:body => {
				:codi => promo_code
			},
			:headers => {"Cookie" => create_cookie_with_session_id(user_login_result.session_id)}
		)
		
		was_promo_code_accepted = @page_parser.was_promo_code_accepted?(submit_response.body)
		total_entries_in_contest = @page_parser.get_total_entries_in_contest(submit_response.body)
		promo_codes_accumulated = @page_parser.get_promo_codes_accumulated(submit_response.body)
		
		PromoCodeSubmitResult.new(was_promo_code_accepted, total_entries_in_contest, promo_codes_accumulated)
	end
	
	private :get_session_id_with_initial_request,
		:get_session_id_from_cookie,
		:create_cookie_with_session_id,
		:did_log_in_succeed?
end

class UserLoginResult
	attr_reader :username, :session_id

	def initialize(username, session_id, did_log_in_succeed)
		@username = username
		@session_id = session_id
		@did_log_in_succeed = did_log_in_succeed
	end
	
	def did_log_in_succeed?
		@did_log_in_succeed
	end
end

# Extracts information from the contest page. Calling it a "parser" is
# a little generous.
class ContestPageParser
	TOTAL_ENTRIES_REGEX = /HAS ACONSEGUIT (?<total_entries>[0-9]+) PARTICIPACIONS PEL SORTEIG/
	PROMO_CODES_ACCUMULATED_REGEX = /JA TENS (?<codes_accumulated>[0-9]+) CODIS ACUMULATS/
	
	INCORRECT_PROMO_CODE_MESSAGE = "CODI INCORRECTE!"

	def was_promo_code_accepted?(response_body)
		# If the "incorrect code" message doesn't show up, we're good
		!response_body.index(INCORRECT_PROMO_CODE_MESSAGE).nil?
	end

	def get_total_entries_in_contest(response_body)
		get_from_response_body_with_regex(
			response_body,
			TOTAL_ENTRIES_REGEX,
			:total_entries)
	end
	
	def get_promo_codes_accumulated(response_body)
		get_from_response_body_with_regex(
			response_body,
			PROMO_CODES_ACCUMULATED_REGEX,
			:codes_accumulated)
	end

	def get_from_response_body_with_regex(response_body, regex, capture_group_symbol)
		match_data = regex.match(response_body)
		
		if match_data.nil?
			return 0
		end
		
		# The symbol name must match the named capture group in the regex
		match_data[capture_group_symbol]
	end
	
	private :get_from_response_body_with_regex
end

class PromoCodeSubmitResult
	attr_reader :was_promo_code_accepted,
		:total_entries_in_contest,
		# Number of promo codes accumulated towards the enxt entry in the contest
		:promo_codes_accumulated
	
	def initialize(was_promo_code_accepted, total_entries_in_contest, promo_codes_accumulated)
		@was_promo_code_accepted = was_promo_code_accepted
		@total_entries_in_contest = total_entries_in_contest
		@promo_codes_accumulated = promo_codes_accumulated
	end
end

# File format is:
#		* First line has username
#		* Second line has password
#		* Following lines promo codes, one per line
class PromoCodeInputFileParser
	def initialize(file_path)
		@file_path = file_path
	end
	
	def username
		read_login_from_file_if_needed
		
		@username
	end
	
	def password
		read_login_from_file_if_needed
		
		@password
	end
	
	def get_promo_codes
		file = File.new(@file_path, "r")
		
		ii = 0
		while(promo_code = file.gets)
			if 2 < ii
				yield promo_code.chomp
			end

			ii = ii + 1
		end
		
		file.close
	end
	
	def read_login_from_file_if_needed
		if !@username.nil?
			return
		end
	
		file = File.new(@file_path, "r")
		
		ii = 0
		while(line = file.gets and ii < 2)
			line = line.chomp
		
			if 0 == ii
				@username = line
			elsif 1 == ii
				@password = line
			end
			
			ii = ii + 1
		end
		
		file.close
	end
	
	private :read_login_from_file_if_needed
end

# Use the contest page interactively
class InteractiveContestShell
	INVALID_PROMO_CODE = "AAAAAAAA"

	def	initialize
		@submitter = PromoCodeSubmitter.new
		@result_formatter = ResultFormatter.new
	end
	
	def log_in
		puts "Username:"
		username = gets.chomp
		
		puts "Password:"
		password = gets.chomp
		
		@log_in_result = @submitter.log_in_user(username, password)
		
		puts @result_formatter.format_log_in_result(@log_in_result)
	end
	
	def submit_promo_code
		return if !is_logged_in
	
		puts "Enter promo code:"
		promo_code = gets.chomp
		
		submit_promo_code_and_print_result(promo_code)
	end
	
	def is_logged_in(log_in_result)
		result = log_in_result || @log_in_result
	
		if result.nil?
			puts "Must be logged in first"
			return false
		end
		
		return true
	end
	
	def submit_promo_code_and_print_result(promo_code, log_in_result = nil)
		log_in_res = log_in_result || @log_in_result
	
		submit_result = @submitter.submit_promo_code(log_in_res, promo_code)
		
		puts @result_formatter.format_promo_code_submit_result(submit_result)
	end
	
	def get_stats(log_in_result = nil)
		result = log_in_result || @log_in_result
	
		return if !is_logged_in(result)
	
		submit_promo_code_and_print_result(INVALID_PROMO_CODE, result)
	end
	
	def operate_with_file
		puts "Enter relative path to file:"
		file_path = gets.chomp
		
		if !does_file_exist?(file_path)
			puts "File '#{file_path}' doesn't exist"
			return
		end
		
		file_parser = PromoCodeInputFileParser.new(file_path)
		
		log_in_result = @submitter.log_in_user(
			file_parser.username,
			file_parser.password
		)
		
		puts @result_formatter.format_log_in_result(log_in_result)
		
		file_parser.get_promo_codes {|promo_code|
			@submitter.submit_promo_code(log_in_result, promo_code)
		}
		
		get_stats(log_in_result)
	end
	
	def does_file_exist?(file_path)
		does_file_exist = true
		
		begin
			file = File.new(file_path, "r")
		rescue
			does_file_exist = false
		ensure
			file.close unless file.nil?
		end
		
		return does_file_exist
	end
	
	def start
		while(true)
			print_menu
			
			choice = get_choice
			chose_to_exit = process_choice(choice)
		
			break if chose_to_exit
		end
	end
	
	def print_menu
		# Whatever indentation is present in the heredoc below will also be
		# Output to the screen
		puts <<-eos
Please enter a number, one of:
1. Log in
2. Submit promo code
3. Get stats
4. Exit
5. Operate with file
eos
	end
	
	def get_choice
		puts "Your choice:"
		gets.chomp
	end
	
	def process_choice(choice)
		case choice
		when "1"
			log_in
		when "2"
			submit_promo_code
		when "3"
			get_stats
		when "4"
			return true
		when "5"
			operate_with_file
		else
			puts "Invalid choice."
		end
		
		return false
	end
	
	private :is_logged_in,
		:submit_promo_code_and_print_result,
		:print_menu,
		:get_choice,
		:process_choice,
		:does_file_exist?
end

# Formats the results of interacting with the page
# 	for consumption by the user
class ResultFormatter
	def format_log_in_result(log_in_result)
		if log_in_result.did_log_in_succeed?
			"Login successful"
		else
			"Login unsuccessful"
		end
	end
	
	def format_promo_code_submit_result(promo_code_submit_result)
		accepted = promo_code_submit_result.was_promo_code_accepted ? 'Y' : 'N'
		entries = promo_code_submit_result.total_entries_in_contest
		codes = promo_code_submit_result.promo_codes_accumulated
		
		"Code accepted? #{accepted} - Entries: #{entries} - Codes: #{codes}/30"
	end
end

InteractiveContestShell.new.start
