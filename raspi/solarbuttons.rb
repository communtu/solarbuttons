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

class Time
  def today?
    t = Time.now
    self.day == t.day and self.mon == t.mon and self.year == t.year
  end 
end

class RaspiControl

require "sqlite3"
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
    # db connection for reading sensor data
    @db = SQLite3::Database.new(SETTINGS[:db]) 
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
          when WAIT_FOR_USER_TO_START then wait_for_user_to_start
          when DEVICE_MENU then device_menu
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
        puts "session[:running]: #{session[:running].inspect}"
      end  
    end
  end
  
  def self.main_menu
    puts "main_menu"
    i=0
    ind=0
    running = session[:running]
    str = ["SolarWash-Steuerung","Wähle ein Gerät aus:"]
    OURDEVICES.each do |name, data|
      if name == @device[0] then
        ind = i
      end  
      i+=1
      str << name
      if !(s=running[name]).blank? 
        if s[:running]
          str << "bis #{s[:end].show}"
          i+=1
        elsif !s[:start].nil? 
          str << "Start #{s[:start].show}"
          i+=1
        end   
      end   
    end
    display(str,ind+2,true)
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
  
  def self.wait_for_user_to_start
    puts "wait_for_user_to_start"
    display("Bitte Wäsche einlegen\nProgramm wählen\nund Maschine starten")
    switch(true)
    # wait for power consumption of more than 30 Watts
    consumption = 0
    while(consumption < 20) do
      last_row = db_last_row(@db)
      puts last_row
      consumption = last_row[1]
    end
    switch(false)
  end

  def self.device_menu
    puts "device_menu"
    strs = [@device[0]]
    if !(s=session[:running][@device[0]]).blank?
      strs << "#{s[:start].strftime('%H:%M')}h - #{s[:end].strftime('%H:%M')}h"
    end
    strs << "Links=zurück"
    strs << "Mitte=sofort starten"
    strs << "Rechts=Zeit ändern"
    display(strs)
  end  
  

  def self.display(s,i=-1,heading=false)
    if s.class==String
      s=s.split("\n")
    end
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
  
  def self.switch(on)
    system "hexaswitch -i #{SETTINGS[:switch_ip]} -c set -e 1 -d 1 -v #{on ? 1 : 0}"
  end
  
  def self.energy_consumption
    return Time.now.sec # dummy implementation
  end
  
  def self.db_last_row(db)
    row = nil
    while row.nil?
      begin
        row = db.execute( "select * from '20cfb985-fb7a-4d5f-acc4-7c10710f85b6' ORDER BY timestamp DESC LIMIT 1")[0]
      rescue
        row = nil
      end
    end
    return row      
  end
  
end
