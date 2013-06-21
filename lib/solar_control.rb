module SolarControl

MAIN_MENU = 0
PROGRAM_SELECTION = 1
TIME_SELECTION = 2
WAIT_FOR_USER_TO_START = 3
DEVICE_MENU = 4

def init_session
  session[:menu] = MAIN_MENU if session[:menu].blank?
  session[:device] = 0 if session[:device].blank?
  session[:program] = [0] if session[:program].blank?
  session[:level] = 0 if session[:level].blank?
  session[:tindex] = 0 if session[:tindex].blank?
  if session[:running].blank? then
    session[:running] = {}
    OURDEVICES.each do |d,i|
      session[:running][d] = {:running => false, :start => nil, :end => nil}
    end  
  end   
  return OURDEVICES.to_a[session[:device].to_i]
end  

def eval_buttons
    @device = OURDEVICES.to_a[session[:device].to_i]
    case session[:menu]
      when MAIN_MENU then
        session[:level] = 0
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
            if level_descend(@device,session[:level],session[:program]).class == Hash then 
              session[:level] += 1
            else
              duration = level_descend(@device,session[:level],session[:program])
              session[:duration] = []
              session[:duration] << duration/60
              session[:duration] << duration%60
              
              session[:time] = Time.now.strftime("%H%M").scanf("%2d"*2)
              
              session[:time][0] = session[:time][0] + session[:duration][0]
              session[:time][1] = session[:time][1] + session[:duration][1]
              adjust_hours_mins
              session[:time][1] += 15 - session[:time][1]%15
              adjust_hours_mins

              session[:ref_time] = session[:time].clone
              session[:day_change_thres] = day_change_thres(session[:ref_time])
              session[:day] = 0 #today

              # debug output
              session[:debug_curr_time] = time_to_mins(session[:time])
              session[:debug_ref_time] = time_to_mins(session[:ref_time])
 
              adjust_day

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
            # debug output
            session[:debug_curr_time] = time_to_mins(session[:time])
            session[:debug_ref_time] = time_to_mins(session[:ref_time])
            adjust_day
        end
     
        when WAIT_FOR_USER_TO_START then
          if params[:dir] == 'left' then session[:menu] -= 1 end
          if params[:dir] == 'right' 
             session[:menu] = MAIN_MENU
             tend = time_to_ruby_time(session[:time],session[:day])
             tstart = tend-60*time_to_mins(session[:duration])
             session[:running][@device[0]] = {:running => false, :start => tstart, :end => tend}  
          end
        when DEVICE_MENU then
          if params[:dir] == 'left' then session[:menu] -= 1 end
    end
    if session[:menu] < 0 then session[:menu] = 0 end   
    if session[:level] < 0 then session[:level] = 0 end   
    session[:device] %= NUMBER_OF_DEVICES
    menu_depth = @device[1]
    for i in (0..session[:program].length-2) do
      menu_depth = menu_depth.to_a[session[:program][i]][1] 
    end
    session[:program][-1] %= menu_depth.length
    return OURDEVICES.to_a[session[:device].to_i]
end

  def adjust_day
    if session[:ref_time] == [ 0, 0 ] then
      session[:day] = 1
    elsif time_to_mins(session[:time]).between?(time_to_mins(session[:ref_time]), session[:day_change_thres]) then
      session[:day] = 0 
    else
      session[:day] = 1
    end
  end

  def adjust_hours_mins
    if session[:time][1] >= 60 then
      session[:time][1] -= 60
      session[:time][0] = (session[:time][0] + 1)%24
    end
  end

  def time_to_mins(time)
    time[0]*60+time[1]
  end
  
  def time_to_ruby_time(time,day)
    (Date.today+day).to_time+60*time_to_mins(time)
  end
    
  def day_change_thres(time)
    time_to_mins(time)+(24-time[0])*60+time[1]
  end

  def level_descend(device,level,program)
    selection = device
    for i in (0..level)
 #    logger.warn "selection #{selection.inspect}"
 #    puts "selection #{selection.inspect}"
      if selection.nil? then return false end
      selection = selection[1].to_a[program[i]]
    end
    return selection[1].to_a[0][1]
  end
  
end