require 'scanf'
require 'solar_control'

include SolarControl

class HomeController < ApplicationController
include SolarControl

  def index
    # initialize cookie and store current device
    @device = init_session
    # initialize time if neccessary and store for future reference
    # uncomment for debug output
  end

  def push_button
    @device = eval_buttons
    redirect_to '/home/index'
  end
  
end
