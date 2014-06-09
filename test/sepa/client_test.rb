require 'test_helper'

class ClientTest < ActiveSupport::TestCase

  def setup
    @params = get_params
    @certparams = get_cert_params
    @danskecertparams = get_danske_cert_params

    # Namespaces
    @cor = 'http://bxd.fi/CorporateFileService'

    observer = Class.new {
      def notify(operation_name, builder, globals, locals)
        @operation_name = operation_name
        @builder = builder
        @globals = globals
        @locals  = locals
        HTTPI::Response.new(200, { "Reponse is actually" => "the request, w0000t" }, locals[:xml])
      end
    }.new

    Savon.observers << observer
  end

  test "should initialize class" do
    assert Sepa::Client.new
  end

  test "should initialize with attributes" do
    assert Sepa::Client.new @params
  end

  test "should set attributes" do
    a = Sepa::Client.new
    assert a.attributes @params
  end

  test "should be valid with required params" do
    sepa = Sepa::Client.new @danskecertparams
    assert sepa.valid?, sepa.errors.messages
  end

  test "not valid if invalid bank" do
    @params[:bank] = :royal_bank_of_skopje
    sepa = Sepa::Client.new @params
    refute sepa.valid?, sepa.errors.messages
  end

  test "banks supported commands" do
    @certparams[:bank] = :danske
    @certparams[:command] = :get_certificate
    sepa = Sepa::Client.new @certparams
    refute sepa.valid?, sepa.errors.messages
  end

  test "private keys are checked" do
    wrong_pks = ['Im not a key', :leppakerttu, nil]

    wrong_pks.each do |wrong_pk|
      @params[:private_key] = wrong_pk
      sepa = Sepa::Client.new @params
      refute sepa.valid?, sepa.errors.messages
    end
  end

  test "private certificates are checked" do
    wrong_certs = ['Im not a cert', 99, :leppakerttu, nil]

    wrong_certs.each do |wrong_cert|
      @params[:cert] = wrong_cert
      sepa = Sepa::Client.new @params
      refute sepa.valid?, sepa.errors.messages
    end
  end

  test "customer id is correct" do
    wrong_ids = ["I'm a way too long a string and probably also not valid", nil]

    wrong_ids.each do |wrong_id|
      @params[:customer_id] = wrong_id
      sepa = Sepa::Client.new @params
      refute sepa.valid?, sepa.errors.messages
    end
  end

  test "environment is correct" do
    wrong_envs = ["not proper", 5, :protuction, nil]

    wrong_envs.each do |wrong_env|
      @params[:environment] = wrong_env
      sepa = Sepa::Client.new @params
      refute sepa.valid?, sepa.errors.messages
    end
  end

  test "status values are correct" do
    wrong_statuses = ["ready", 'steady', 5, :nipsu]

    wrong_statuses.each do |wrong_status|
      @params[:status] = wrong_status
      sepa = Sepa::Client.new @params
      refute sepa.valid?, sepa.errors.messages
    end
  end

  test "target id is valid" do
    wrong_ids = ["ready"*81, nil]
    @params[:command] = :upload_file

    wrong_ids.each do |wrong_id|
      @params[:target_id] = wrong_id
      sepa = Sepa::Client.new @params
      refute sepa.valid?, sepa.errors.messages
    end
  end

  test "language values are valid" do
    wrong_langs = ["Joo", 7, :protuction]

    wrong_langs.each do |wrong_lang|
      @params[:language] = wrong_lang
      sepa = Sepa::Client.new @params
      refute sepa.valid?, sepa.errors.messages
    end
  end

  test "file type is valid" do
    wrong_types = ["kalle"*41, nil]

    wrong_types.each do |wrong_type|
      [:upload_file, :download_file_list].each do |command|
        @params[:command] = command
        @params[:file_type] = wrong_type
        sepa = Sepa::Client.new @params
        refute sepa.valid?, sepa.errors.messages
      end
    end
  end

  test "content is required" do
    @params[:command] = :upload_file
    @params.delete(:content)
    sepa = Sepa::Client.new @params
    refute sepa.valid?, sepa.errors.messages
  end

  # # The response from savon will be the request to check that a proper request
  # # was made in the following four tests
  def test_should_send_proper_request_with_get_user_info
    @params[:command] = :get_user_info
    client = Sepa::Client.new(@params)
    response = client.send_request

    assert response.document.at_css('cor|getUserInfoin', cor: @cor)

    Dir.chdir(SCHEMA_PATH) do
      xsd = Nokogiri::XML::Schema(IO.read('soap.xsd'))
      assert xsd.valid?(response.document)
    end
  end

  def test_should_send_proper_request_with_download_file_list
    @params[:command] = :download_file_list
    client = Sepa::Client.new(@params)
    response = client.send_request

    assert response.document.at_css('cor|downloadFileListin', cor: @cor)

    Dir.chdir(SCHEMA_PATH) do
      xsd = Nokogiri::XML::Schema(IO.read('soap.xsd'))
      assert xsd.valid?(response.document)
    end
  end

  def test_should_send_proper_request_with_download_file
    @params[:command] = :download_file
    client = Sepa::Client.new(@params)
    response = client.send_request

    assert response.document.at_css('cor|downloadFilein', cor: @cor)

    Dir.chdir(SCHEMA_PATH) do
      xsd = Nokogiri::XML::Schema(IO.read('soap.xsd'))
      assert xsd.valid?(response.document)
    end
  end

  def test_should_send_proper_request_with_upload_file
    @params[:command] = :upload_file
    client = Sepa::Client.new(@params)
    response = client.send_request

    assert response.document.at_css('cor|uploadFilein', cor: @cor)

    Dir.chdir(SCHEMA_PATH) do
      xsd = Nokogiri::XML::Schema(IO.read('soap.xsd'))
      assert xsd.valid?(response.document)
    end
  end

  def test_should_initialize_with_proper_cert_params
    assert Sepa::Client.new(@certparams)
  end

  def test_should_send_proper_request_with_get_certificate
    client = Sepa::Client.new(@certparams)
    response = client.send_request

    assert response.document.at_css('cer|getCertificatein')

    Dir.chdir(SCHEMA_PATH) do
      xsd = Nokogiri::XML::Schema(IO.read('soap.xsd'))
      assert xsd.valid?(response.document)
    end
  end

  def test_should_raise_error_if_signing_pkcs_plain_and_path_missing_with_create_certificate
    @danskecertparams[:command] = :create_certificate
    @danskecertparams.delete(:signing_cert_pkcs10)

    refute Sepa::Client.new(@danskecertparams).valid?
  end

  def test_should_raise_error_if_encryption_pkcs_missing_with_create_certificate
    @danskecertparams[:command] = :create_certificate
    @danskecertparams.delete(:encryption_cert_pkcs10)

    refute Sepa::Client.new(@danskecertparams).valid?
  end

  def test_should_raise_error_if_pin_missing_with_create_certificate
    @danskecertparams[:command] = :create_certificate
    @danskecertparams.delete(:pin)

    refute Sepa::Client.new(@danskecertparams).valid?
  end

  def test_should_raise_error_if_encryption_cert_missing_with_create_certificate
    @danskecertparams[:command] = :create_certificate
    @danskecertparams.delete(:enc_cert)

    refute Sepa::Client.new(@danskecertparams).valid?
  end

end
