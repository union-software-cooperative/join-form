class PeopleController < ApplicationController
  before_action :set_person, only: [:show, :edit, :update, :destroy, :compose_email, :send_email, :compose_sms, :send_sms]
  before_action :forbid, only: [:show, :edit, :update, :destroy]
  skip_before_filter :verify_authenticity_token, :only => "receive_sms"
  skip_before_filter :authenticate_person!, :only => "receive_sms"

  # GET /people
  # GET /people.json
  def index

    @people = Person.filter(params.slice(:name_like))
    @people = @people.where(["union_id = ?", current_person.union_id]) if request.format.json? && !owner?
    @people = @people.where("not invited_by_id is null").order([:last_name, :first_name, :id])
  
    respond_to do |format|
      format.html 
      format.json 
    end
  end

  # GET /people/1
  # GET /people/1.json
  def show
  end

  # GET /people/1/edit
  def edit
  end

  # PATCH/PUT /people/1
  # PATCH/PUT /people/1.json
  def update
    @person.authorizer = current_person

    respond_to do |format|
      if @person.update(person_params)
        @person.invite!(current_person) if params['resend_invite']=='true' 
        
        format.html { redirect_to :people, notice: 'Profile successfully updated.' }
        format.json { render :show, status: :ok, location: @person }
      else
        format.html { render :edit }
        format.json { render json: @person.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /people/1
  # DELETE /people/1.json
  def destroy
    @person.destroy rescue nil
    respond_to do |format|
      if @person.destroyed?
        format.html { redirect_to request.referer || subscriptions_url, notice: 'Person was successfully destroyed.' }
        format.json { head :no_content }
      else
        format.html { redirect_to request.referer || edit_person_path(@person), notice: "Could not delete person, probably because they've posted content.  TODO Create a way to deactivate and hide people."
        }
        format.json { render json: @person.errors, status: :unprocessable_entity }
      end
    end
  end

  def compose_email
  end

  def send_email
      PersonMailer.private_email(@person, current_person, params[:subject], params[:body]).deliver_now     
      redirect_to people_url, notice: "Email sent..."  
  end  

  def compose_sms
    @body = "hi #{@person.first_name}, please update your union membership details here #{root_url}#{subscription_form_path(@person.subscriptions.last)}, #{current_person.first_name}, #{current_person.union.short_name}"
  end

  def send_sms
    @client = Twilio::REST::Client.new ENV["twilio_sid"], ENV["twilio_token"]
    sms = @client.messages.create(
      from: ENV["twilio_number"],
      to: @person.mobile,
      body: params[:body]
    )
    redirect_to subscriptions_url, notice: "SMS sent..."  
  end

  def receive_sms
    from = Person.find_by_mobile(params['From'].gsub('+61', '0'))
    PersonMailer.private_email(current_person, from, 'SMS Reply from #{from.first_name} #{from.last_name}', params[:body], request).deliver_now     
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_person
      @person = Person.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def person_params
      params.require(:person).permit(:first_name, :last_name, :title, :address1, :address2, :suburb, :state, :postcode, :mobile, :email, :attachment, :union_id, :gender)
    end

    def forbid
      return forbidden if params[:action] == "destroy" && !owner?
      return forbidden unless can_edit_union?(@person.union)
    end
end
