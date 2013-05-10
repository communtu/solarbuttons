require 'scanf'

MAIN_MENU = 0
PROGRAM_SELECTION = 1
TIME_SELECTION = 2
WAIT_FOR_START = 3

class HomeController < ApplicationController
  def index
    session[:menu] = MAIN_MENU if session[:menu].blank?
    session[:device] = 0 if session[:device].blank?
    session[:program] = [0] if session[:program].blank?
    session[:level] = 0 if session[:level].blank?
    session[:tindex] = 0 if session[:tindex].blank?
    if session[:time].blank? then
      session[:time] = Time.now.strftime("%H%M").scanf("%2d"*2)
      session[:time][0] += 2
      session[:time][1] = session[:time][1] - session[:time][1]%15
      session[:ref_time] = session[:time]
      session[:day] = 0 #today
    end
    @current_time = time_to_mins(session[:time])
    @ref_time = time_to_mins(session[:ref_time])
    @device = OURDEVICES.to_a[session[:device].to_i]
  end

  def push_button
    @device = OURDEVICES.to_a[session[:device].to_i]
    case session[:menu]
      when MAIN_MENU then
        case params[:dir]
          when 'up', 'down' then session[:device] += if params[:dir] == 'up' then -1 else 1 end
            session[:program] = [0]
          when 'center', 'right' then session[:menu] += 1
          when 'left' then session[:menu] -= 1
        end
      when PROGRAM_SELECTION then
        case params[:dir]
          when 'up', 'down' then
            session[:program][session[:level]] += if params[:dir] == 'up' then -1 else 1 end
            if session[:level] < session[:program].length then session[:program] = session[:program][0..session[:level]]
            end
          when 'center', 'right' then 
            if has_next(@device,session[:level],session[:program]) then 
              session[:level] += 1
            else
              session[:menu] += 1
            end
            session[:program] << 0 unless session[:program].length > session[:level]
          when 'left' then
           if session[:level] > 0 
           then session[:level] -= 1
           else session[:menu] -= 1
           end
        end
      when TIME_SELECTION then
        case params[:dir]
          when 'right' then session[:tindex]+=1
            if session[:tindex] > 1 then
              session[:menu] += 1 
              session[:tindex] = 1
            end
          when 'left' then session[:tindex]-=1
            if session[:tindex] < 0 then 
              session[:menu] -= 1 
              session[:tindex] = 0
            end
          when 'center' then session[:menu] += 1
          when 'up', 'down' then
            if session[:tindex] == 0 then
              session[:time][session[:tindex]] = (session[:time][session[:tindex]] + (params[:dir] == 'up' ? 1 : -1))%24
            else
              session[:time][session[:tindex]] = (session[:time][session[:tindex]] + (params[:dir] == 'up' ? 15 : -15))%60
            end
            if time_to_mins(session[:ref_time]) < time_to_mins(session[:time]) then session[:day] +=1 end
        end           
     
        when WAIT_FOR_START then
          if params[:dir] == 'left' then session[:menu] -= 1 else true end
    end
    if session[:menu] < 0 then session[:menu] = 0 end   
    if session[:level] < 0 then session[:level] = 0 end   
    session[:device] %= NUMBER_OF_DEVICES
    menu_depth = @device[1]
    for i in (0..session[:program].length-2) do
      menu_depth = menu_depth.to_a[session[:program][i]][1] 
    end
    redirect_to '/home/index'
  end

  def time_to_mins(time)
    time[0]*60+time[1]
  end
  
  private
  def has_next(device,level,program)
    selection = device
    for i in (0..level)
      logger.warn "selection #{selection.inspect}"
      puts "selection #{selection.inspect}"
      if selection.nil? then return false end
      selection = selection[1].to_a[program[i]]
    end
    return selection[1].to_a[0][1].class == Hash
  end
end
