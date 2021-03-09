require 'net/http'
require 'securerandom'
require 'json'
require 'date'

class UntisWorker
  attr_accessor :login, :password, :client_id,
                :session_id, :person_id, :person_type,
                :api_base_url, :school_name, :school_name_url,
                :api_url, :api_url_base, :api_version,
                :api_version_sv

  def initialize(**args)
    @login            = args[:login]
    @password         = args[:password]
    @client_id        = args[:client_id]    || self.generate_client_id
    @session_id       = args[:session_id]
    @person_id        = args[:person_id]
    @person_type      = args[:person_type]
    @api_base_url     = args[:api_base_url] || "https://kephiso.webuntis.com/WebUntis"
    @school_name      = args[:school_name]  || "Example School"
    @school_name_url  = URI.encode_www_form_component @school_name
    @api_url_base     = URI "#{@api_base_url}/jsonrpc.do"
    @api_url          = URI "#{@api_base_url}/jsonrpc.do?school=#{@school_name_url}"
    @api_version      = '2.0'
    @api_version_sv   = @api_version
  end

  def generate_client_id
    "UW-#{SecureRandom.hex}"
  end

  def generate_id
    SecureRandom.hex
  end

  private

  def build_fields(**args)
    { 'id' => generate_id, 'jsonrpc' => @api_version, 'method' => args[:method], 'params' => args[:params].delete_if do |k, v| v.nil? end }
  end

  def post(url, data)
    response = nil

    data.delete_if do |k, v|
      v.nil?
    end

    begin
      if @session_id.nil?
        response = Net::HTTP.post url, data.to_json, 'Content-Type' => 'application/json'
      else
        response = Net::HTTP.post url, data.to_json, 'Content-Type' => 'application/json', 'Cookie' => "JSESSIONID=#{@session_id}"
      end
    rescue
      puts 'Request failed!'
      sleep 1
      puts 'Retrying...'
      return post url, data
    end

    response_data = JSON.parse response.body

    # Catch non-auth
    if response_data['error'] && (response_data['error']['code'] == -8520 || response_data['error']['message'] == 'not authenticated')
      puts 'Request failed, authentication expired! Re-Authing...'
      sleep 0.25
      authenticate!
      sleep 1
      puts 'Retrying...'
      return post url, data
    end

    response_data
  end

  public

  def date_from_str(date_str)
    Date::strptime date_str, '%Y%m%d'
  end

  def date_to_str(date)
    date.strftime '%Y%m%d'
  end

  def time_from_str(time_str)
    Time::strptime time_str, '%H%M'
  end

  def time_to_str(time)
    time.strftime '%H%M'
  end

  def authenticate!
    result = post @api_url, build_fields(
      method: 'authenticate',
      params: {
        'user'      => @login,
        'password'  => @password,
        'client'    => @client_id
      }
    )

    if result['result']
      puts 'Auth OK!'

      @session_id     = result['result']['sessionId']
      @person_type    = result['result']['personType']
      @person_id      = result['result']['personId']
      @api_version_sv = result['jsonrpc']
    else
      puts 'Auth error!'
      puts result['error']['message']
    end

    result
  end

  def get_teachers
    post @api_url, build_fields(
      method: 'getTeachers',
      params: []
    )
  end

  def get_students
    post @api_url, build_fields(
      method: 'getStudents',
      params: []
    )
  end

  def get_classes(**args)
    post @api_url, build_fields(
      method: 'getKlassen',
      params: {
        schoolyearId: args[:school_year] || args[:year] || args[:schoolyearId] || args[:school_year_id]
      }
    )
  end

  def get_subjects
    post @api_url, build_fields(
      method: 'getSubjects',
      params: []
    )
  end

  def get_rooms
    post @api_url, build_fields(
      method: 'getRooms',
      params: []
    )
  end

  def get_departments
    post @api_url, build_fields(
      method: 'getDepartments',
      params: []
    )
  end

  def get_holidays
    post @api_url, build_fields(
      method: 'getHolidays',
      params: []
    )
  end

  def get_timegrid
    post @api_url, build_fields(
      method: 'getTimegridUnits',
      params: []
    )
  end

  def get_status_data
    post @api_url, build_fields(
      method: 'getStatusData',
      params: []
    )
  end

  def get_current_school_year
    post @api_url, build_fields(
      method: 'getCurrentSchoolyear',
      params: []
    )
  end

  def get_school_years
    post @api_url, build_fields(
      method: 'getSchoolyears',
      params: []
    )
  end

  def get_timetable(**args)
    if args[:options].nil?
      post @api_url, build_fields(
        method: 'getTimetable',
        params: {
          id:         args[:id],
          type:       args[:type],
          startDate:  date_to_str(args[:start_date] || args[:startDate]),
          endDate:    date_to_str(args[:end_date]   || args[:endDate])
        }
      )
    else
      opts = args[:options]
  
      post @api_url, build_fields(
        method: 'getTimetable',
        params: {
          options: {
            element: {
              id:               opts[:element][:id],
              type:             opts[:element][:type],
              keyType:          opts[:element][:key_type]     || opts[:element][:keyType] || 'id'
            },
            startDate:          date_to_str(opts[:start_date] || opts[:startDate]         || Date.today),
            endDate:            date_to_str(opts[:end_date]   || opts[:endDate]           || Date.today),
            onlyBaseTimetable:  opts[:only_base_timetable]    || opts[:onlyBaseTimetable] || false,
            showBooking:        opts[:show_booking]           || opts[:showBooking]       || false,
            showInfo:           opts[:show_info]              || opts[:showInfo]          || false,
            showSubstText:      opts[:show_subst_text]        || opts[:showSubstText]     || false,
            showLsText:         opts[:show_ls_text]           || opts[:showLsText]        || false,
            showStudentgroup:   opts[:show_student_group]     || opts[:showStudentgroup]  || false,
            klasseFields:       opts[:class_fields]           || opts[:klasseFields],
            roomFields:         opts[:room_fields]            || opts[:roomFields],
            subjectFields:      opts[:subject_fields]         || opts[:subjectFields],
            teacherFields:      opts[:teacher_fields]         || opts[:teacherFields]
          }
        }
      )
    end
  end

  def get_latest_import_time
    post @api_url, build_fields(
      method: 'getLatestImportTime',
      params: []
    )
  end

  def get_person_id(**args)
    post @api_url, build_fields(
      method: 'getPersonId',
      params: {
        type: args[:type] || 5,
        sn:   args[:sn]   || args[:surname]   || args[:last_name],
        fn:   args[:fn]   || args[:forename]  || args[:name]        || args[:first_name],
        dob:  args[:dob]  || args[:birthday]  || args[:birth_date]  || 0,
      }
    )
  end

  def get_substitutions(**args)
    post @api_url, build_fields(
      method: 'getSubstitutions',
      params: {
        endDate:      date_to_str(args[:end_date]   || args[:endDate]),
        startDate:    date_to_str(args[:start_date] || args[:startDate]),
        departmentId: args[:department_id]          || args[:departmentId] || 0,
      }
    )
  end

  def get_class_reg_events(**args)
    post @api_url, build_fields(
      method: 'getClassregEvents',
      params: {
        endDate:    args[:end_date]     || args[:endDate],
        startDate:  args[:start_date]   || args[:startDate],
      }
    )
  end

  def get_exams(**args)
    post @api_url, build_fields(
      method: 'getExams',
      params: {
        endDate:    args[:end_date]     || args[:endDate],
        startDate:  args[:start_date]   || args[:startDate],
        examTypeId: args[:exam_type_id] || args[:exam_type] || args[:examTypeId] || args[:exam_id]
      }
    )
  end

  def get_exam_types
    post @api_url, build_fields(
      method: 'getExamTypes',
      params: []
    )
  end

  def get_timetable_with_absences(**args)
    opts = args[:options] || args
  
    post @api_url, build_fields(
      method: 'getTimetableWithAbsences',
      params: {
        options: {
          endDate:    opts[:end_date]   || opts[:endDate],
          startDate:  opts[:start_date] || opts[:startDate]
        }
      }
    )
  end

  def get_class_reg_categories
    post @api_url, build_fields(
      method: 'getClassregCategories',
      params: []
    )
  end

  def get_class_reg_category_groups
    post @api_url, build_fields(
      method: 'getClassregCategoryGroups',
      params: []
    )
  end

  def get_class_reg_events_for_element(**args)
    opts = args[:options] || args

    opts[:element] = {} if opts[:element].nil?

    post @api_url, build_fields(
      method: 'getClassregEvents',
      params: {
        options: {
          endDate:    opts[:end_date]           || opts[:endDate],
          startDate:  opts[:start_date]         || opts[:startDate],
          element: {
            id:       opts[:element][:id],
            type:     opts[:element][:type],
            keyType:  opts[:element][:keyType]  || opts[:element][:key_type] || 'id',
          }
        }
      }
    )
  end
end
