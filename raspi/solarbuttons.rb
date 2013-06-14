# encoding: UTF-8
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
    screen_saver_cnt = 0 
    loop do
      sleep_ms(200)
      screen_saver_cnt += 200 
      if screen_saver_cnt > 10000
        set_backlight(0)        
        screen_saver_cnt = 0 
      end 
      update_buttons
      bp = buttons_pressed
      if !bp.empty?
        screen_saver_cnt = 0 
        set_backlight(1)
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
    i=0
    ind=0
    s=OURDEVICES.map do |name, data|
      if name == @device[0] then
        ind = i
        i+=1
        name
      else
        i+=1
        name 
      end
    end
    s = ["SolarWash-Steuerung","Spare Energie","","Wähle ein Gerät aus:"]+s
    display(s,ind+4,true)
  end
  
  def self.program_selection
    puts "program_selection"
    s = [@device[0]]
    selection = @device[1].to_a
    for level in 0..session[:level] do
      if level==session[:level]      
        0.upto(selection.length-1) do |device|
          s << selection[device][0]
        end
      end    
      if selection[session[:program][level]].nil? then 
        selection = 0
      else 
        selection = selection[session[:program][level]][1].to_a
      end
    end   
    display(s,session[:program][session[:level]]+1,true)
  end
  
  def self.time_selection
    puts "time_selection"
    clear_screen
    msg = []
    msg << "Dauer des Programms:"
    msg << "#{session[:duration][0]}:#{session[:duration][1]}"
    msg << "Wann soll die Maschi-"
    msg << "ne spätestens"
    msg << "fertig sein?"
    d = if session[:day] == 0 then "Heute" else "Morgen" end
    s = ""  
    (0..session[:time].length-1).each do |digit| 
      if digit == 1 
         s << ":"
      end  
      if digit == session[:tindex] then
        s << "[" 
      end 
      s << "%02d" % session[:time][digit] 
      if digit == session[:tindex] then 
        s << "]" 
      end 
    end 
    msg << "#{d} um #{s} Uhr"
    display(msg)
  end
  
  def self.wait_for_start
    puts "wait_for_start"
    print_encoded_xy(0,4,"Bitte Maschine")
    print_encoded_xy(0,14, "starten")
    write_framebuffer
  end

  def self.display(s,i=-1,heading=false)
    # we can display at most 6 strings
    s_ind = 0
    e_ind = s.length-1
    if e_ind > 5 then
      s_ind = [i-2,0].max
      e_ind = [s_ind+5,s.length-1].min
    end
    y = 0
    for j in (s_ind..e_ind) do
      if heading and j==s_ind then
        str = s[0][0,21]        
      else
        str = s[j][0,21]
      end  
      print_encoded_xy(0,y, str+(if i==j then "<--" else "" end)) 
      y+=10
      if heading and j==s_ind then
        for x in (0..(6*s[0].length))
          put_pixel(x,y,1)
        end
        y+=4
      end
    end
    write_framebuffer
  end  
end
