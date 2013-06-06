require 'scanf'
require 'lib/solar_control'
require 'raspi_lcd'
require 'yaml'

include SolarControl
include RaspiLCD

SETTINGS = YAML.load_file("config/settings.yml")
devices= YAML.load_file("config/devices.yml")
OURDEVICES = Hash[SETTINGS[:devices].map do |our_name, device_name|
  [our_name, devices[device_name]]
end]
NUMBER_OF_DEVICES = OURDEVICES.length
OURDEVICES_ARRAY = OURDEVICES.to_a

# some useful helpers from rails
class Object
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end
end
class RaspiControl

include SolarControl

  def self.session
    @session
  end
  
  def self.params
    @params
  end
  
  def self.start
    # initialize session and store current device
    @session = {}
    @params = {}
    @device = init_session
    # initialise raspi LCD display
    raspi_lcd_hw_init 
    init
    clear_screen
    set_backlight(1)
    set_font(0)
    main_menu 
    loop do
      sleep_ms(200)
      update_buttons
      bp = buttons_pressed
      if !bp.empty?
        params[:dir] = buttons.first.to_s # we assume that just one button is pressed
        @device = eval_buttons
        #display
        clear_screen
        case session[:menu] 
          when MAIN_MENU then main_menu
          when PROGRAM_SELECTION then program_selection
          when TIME_SELECTION then time_selection
          when WAIT_FOR_START then wait_for_start
        end
        #debug info        
        puts "params[:dir]: #{params[:dir]}"
        puts "session[:menu]: #{session[:menu]}"
        puts "session[:menu]: #{session[:menu]}"
        puts "session[:device]: #{session[:device]}"
        puts "session[:program]: #{session[:program]}"
        puts "session[:level]: #{session[:level]}"
        puts "session[:time]: #{session[:time]}"
        puts "session[:tindex]: #{session[:tindex]}"
        puts "time_to_mins(session[:ref_time]): #{session[:debug_ref_time]}" 
        puts "time_to_mins(session[:time]): #{session[:debug_curr_time]}" 
        puts "session[:day_change_thres]: #{session[:day_change_thres]}"
      end  
    end
  end
  
  def self.main_menu
    puts "main_menu"
    y = 4
    OURDEVICES.each do |name, data|
      if name == @device[0] 
        print_xy(0,y, name+"<--") 
      else
        print_xy(0,y, name) 
      end
      y+=10
    end
    write_framebuffer
  end
  
  def self.program_selection
    puts "program_selection"
  end
  
  def self.time_selection
    puts "time_selection"
  end
  
  def self.wait_for_start
    puts "wait_for_start"
  end
  
end
