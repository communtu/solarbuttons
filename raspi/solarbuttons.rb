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
  
  def self.start
    # initialize session and store current device
    @session = {}
    @device = init_session
    params = {}
    # initialise raspi LCD display
    raspi_lcd_hw_init 
    init
    clear_screen
    set_backlight(1)
    set_font(0) 
    loop do
      update_buttons
      bp = buttons_pressed
      if !bp.empty?
        params[:dir] = buttons.first # we assume that just one button is pressed
        @device = eval_buttons
        #display
        case session[:menu] 
          when MAIN_MENU then main_menu
          when PROGRAM_SELECTION then program_selection
          when TIME_SELECTION then time_selection
          when WAIT_FOR_START then wait_for_start
        end
      end  
    end
  end
  
  def self.main_menu
    y = 4
    OURDEVICES.each do |name, data|
      if name == @device[0] 
        print_xy(0,y, name+"<--") 
      else
        print_xy(0,y, name) 
      end
      y+=10
    end
  end
  
  def self.program_selection
   
  end
  
  def self.time_selection
   
  end
  
  def self.wait_for_start
   
  end
  
end
