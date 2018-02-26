class UsersController < ApplicationController
  skip_before_action :authenticate_request, only: [:create, :show_public]

  def create
    u = User.find_by_email params[:email]
    if u
      render json: { error: 'User exist' }, status: :bad_request
    else
      user = User.new email: params[:email], password: params[:password], password_confirmation: params[:password_confirmation]
      if user.save
        render json: user, status: :created
      else
        render json: { error: 'Error occurred review passwords or check logs' }, status: :bad_request
      end
    end
  end

  def update
    user = current_user

    if user
      user.first_name = params[:first_name]
      user.last_name = params[:last_name]
      user.age = params[:birth_date]
      user.sex = params[:sex]
      user.zip_code = params[:zip]
      user.phone_number = params[:phone_number]
      user.save! ? (render json: user, status: :ok) : (render json: { error: 'Error occurred while saving changes' }, status: :bad_request)
    else
      render json: { error: 'Error occurred while saving changes' }, status: :bad_request
    end
  end

  def show
    render json: current_user, status: :ok
  end

  def show_public
    render json: User.sanitize_atributes(params[:id]), status: :ok
  end

  # Hair dressser methods

  def bind_hair_dresser
    user = current_user
    if user
      hairdresser_info = HairDresser.new(
        is_independent: params[:is_independent],
        longitud: params[:longitude],
        latitud: params[:latitude],
        description: params[:description],
        online_payment: params[:online_payment],
        state: params[:state]
      )
      user.hair_dresser = hairdresser_info
      user.id_hairdresser = true
      user.save!

      hairdresser_info.save! ? (render json: { user: user, hairdresser_info: hairdresser_info }, status: :ok) : (render json: { error: 'Error occurred while saving changes' }, status: :bad_request)
    else
      render json: { error: 'Error occurred while saving changes' }, status: :bad_request
    end
  end

  def unbind_hair_dresser
    user = current_user
    user.hair_dresser = nil
    user.id_hairdresser = false
    user.save!
    render json: { user: user, hairdresser_info: user.hair_dresser }, status: :ok
  end

  # Image methods

  def add_image
    user = current_user
    picture = params[:picture]
    main = params[:main]
    image = Picture.new(image: picture)
    if user.hair_dresser
      user.hair_dresser.pictures << image
      if main.eql? 'true'
        user.hair_dresser.picture = image
      end
      image.save!
      user.hair_dresser.save!
      render json: user.hair_dresser.pictures.all.to_json(methods: [:images]), status: :ok
    else
      render json: { error: 'No hairdresser status associated' }, status: :bad_request
    end
  end

  def remove_image
    user = current_user
    picture = Picture.find params[:id]
    user.hair_dresser.pictures.destroy(picture)
    render json: user.hair_dresser.pictures.all.to_json(methods: [:images]), status: :ok
  end

  # Timetable methods

  def get_timetable
    user = current_user
    render json: user.hair_dresser.time_table.time_sections, status: :ok
  end

  def get_a_time_table
    begin
      start_date = params[:s_day] || Time.now
      end_date = params[:e_day] || Time.now + 7.days

      p start_date, end_date

      time_table = (HairDresser.find params[:h_id]).time_table
      time_sections = time_table.time_sections.where(day: params[:day])
      breaks = time_sections.each { |ts| ts.breaks }
      absences = time_table.absences.where("day >= ? AND day <= ?", start_date, end_date)
      render json: { time_sections: time_sections, breaks: breaks, absences: absences }, status: :ok
    rescue => e
      render json: { error: e }, status: :bad_request
    end
  end

  def modify_timetable
    collides = collision_with_day? params[:timetable_params][:content]
    if !(collides)[:collision]
      tt = add_a_timetable(params[:timetable_params][:content])
      render json: tt, status: :ok
    else
      render json: collides, status: :conflict
    end
  end

  def update_time_section
    begin
      time_section = current_user.hair_dresser.time_table.time_sections.find(params[:time_section_id])
      time_section.update!(params[:time_section_params].permit!)
      render json: time_section, status: :ok
    rescue => e
      render json: { error: e }, status: :bad_request
    end
  end

  def delete_time_section
    user = current_user
    begin
      (user.hair_dresser.time_table.time_sections.find params[:id]).destroy!
      render json: {}, status: :ok
    rescue => e
      render json: { error: e }, status: :bad_request
    end
  end

  def collision_check
    begin
      collides = collision_with_day? params[:timetable_params][:content]
      render json: collides, status: :ok
    rescue => e
      render json: { error: e }, status: :bad_request
    end
  end

  def add_break
    begin
      time_sectio = current_user.hair_dresser.time_table.time_sections.find params[:time_section_id]
      time_sectio.breaks << Break.create!(day: params['day'],
                                          init: params['init'],
                                          duration: params['duration'],
                                          time_section: time_sectio)
      render json: time_sectio.breaks, status: :ok
    rescue => e
      render json: { error: e }, status: :bad_request
    end
  end

  def delete_break
    begin
      time_sectio = current_user.hair_dresser.time_table.time_sections.find params[:time_section_id]
      break_ = time_sectio.breaks.find params[:break_id]
      break_.destroy!
      render json: time_sectio.breaks, status: :ok
    rescue => e
      render json: { error: e }, status: :bad_request
    end
  end

  def add_absence
    begin
      time_table = current_user.hair_dresser.time_table
      time_table.absences << Absence.create!(day: params['day'],
                                             init: params['init'],
                                             duration: params['duration'],
                                             time_table: time_table)
      render json: time_table.absences, status: :ok
    rescue => e
      render json: { error: e }, status: :bad_request
    end
  end

  def delete_absence
    begin
      (current_user.hair_dresser.time_table.absences.find params[:absence_id]).destroy!
      render json: current_user.hair_dresser.time_table.absences, status: :ok
    rescue => e
      render json: { error: e }, status: :bad_request
    end
  end

  # Bookmarks methods

  def get_bookmark
    render json: current_user.bookmarks, status: :ok
  end

  def add_bookmark
    begin
      type = params[:type]
      id = params[:entity_id]
      Bookmark.create!(
        user: current_user,
        entity: (type.eql? 'hairdresser') ? (HairDresser.find id) : (Store.find id)
      )
      get_bookmark
    rescue => e
      render json: { error: e }, status: :bad_request
    end
  end

  def remove_bookmark
    begin
      current_user.bookmarks.find params[:id_bookmark].destroy!
      render json: current_user.bookmarks, status: :ok
    rescue => e
      render json: { error: e }, status: :bad_request
    end
  end

  # Bookings methods

  def bookings
    begin
      render json: current_user.appointments
    rescue => e
      render json: { error: e }, status: :bad_request
    end
  end

  def add_booking
    begin
      type = params[:type]
      id = params[:entity_id]

      Appointment.create!(
          handler: (type.eql? 'hairdresser') ? (HairDresser.find id) : (Store.find id),
          user: current_user,
          service: (Service.find params[:service_id]),
          book_time: params[:book_time],
          book_notes: params[:book_notes],
          book_date: params[:book_date],
          state: true
      )

      bookings

    rescue => e
      render json: { error: e }, status: :bad_request
    end
  end

  def remove_booking
    begin
      booking = (current_user.appointments.find params[:booking_id])
      booking.state = false
      booking.save!
      bookings
    rescue => e
      render json: { error: e }, status: :bad_request
    end
  end

  private

  def add_a_timetable(content)
    user_t = current_user.hair_dresser

    unless user_t.time_table
      user_t.time_table = TimeTable.create!(handler: user_t)
    end

    tt = TimeSection.create!(day: content['day'],
                             init: content['init'],
                             end: content['end'],
                             time_table: user_t.time_table)

    user_t.time_table.time_sections << tt
    tt
  end

  def collision_with_day?(content)
    user = current_user

    init = content['init']
    fin = content['end']
    time_table = user.hair_dresser.time_table

    if time_table
      time_table.time_sections.where(day: content['day']).each do |ts|
        if  (init <= ts.init && fin > ts.init) ||
            (fin >= ts.end && init < ts.end) ||
            (init >= ts.init && fin <= ts.end) ||
            (init <= ts.init && fin >= ts.end)
          p true
          return { collision: true, cause: ts }
        else
          return { collision: false, cause: nil }
        end
      end
      { collision: false, cause: nil }
    else
      { collision: false, cause: nil }
    end
  end
end
