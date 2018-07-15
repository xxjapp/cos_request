#!/usr/bin/env ruby
# encoding: utf-8
#
# Introduction:
#   验证腾讯云对象存储服务COS的文件上传和下载API
#
#   参考：https://cloud.tencent.com/document/product/436/7778
#

require 'cgi'
require 'colorize'
require 'openssl'
require 'ostruct'
require 'rest-client'

################################################################
# Configuration

# TODO: 注意改成自己的配置，下面的配置并不是真实的
Conf = OpenStruct.new \
    appid:      '1244057171',
    secret_id:  'tvUS9R0llq6U2IDfV4ER6tA8KsFd0ZxcVAcw',
    secret_key: 'MT1Yjc1a4ymrg6hq2TtOFf96tGl0a38U',
    host:       'def-1244057171.cos.ap-chongqing.myqcloud.com'

################################################################
# class CosRequest

class CosRequest
    attr_accessor :http_method, :uri, :headers, :body
    attr_accessor :response, :time_used

    def initialize options
        self.http_method    = options[:http_method]
        self.uri            = options[:uri]
        self.headers        = options[:headers] || {}
        self.body           = options[:body]

        self.headers['Authorization'] = get_authorization if options[:sign]
    end

    def self.get uri, options = {}
        self.new(options.merge http_method: 'get', uri: uri).execute
    end

    def self.put uri, options = {}
        self.new(options.merge http_method: 'put', uri: uri, sign: true).execute
    end

    def execute
        start_time = Time.now

        begin
            puts description

            self.response = RestClient::Request.execute(
                method:     http_method,
                url:        "https://#{Conf.host}#{uri}",
                headers:    headers,
                payload:    body,
                verify_ssl: false
            )
        rescue => e
            self.response = e.response
        ensure
            end_time = Time.now
            self.time_used = (end_time - start_time)
            puts response_description
        end

        m = /attachment; filename\*="UTF-8''(.+)"/.match response.headers[:content_disposition]
        IO.binwrite(m[1], response) if m
    end

private

    def description
        s = "\n\n"
        s << "#{http_method.upcase} #{uri} HTTP/1.1\n".light_magenta

        headers.each do |k, v|
            s << "#{k}: #{v}\n".red
        end if headers

        s << "\n"
        s << body << "\n" if body

        return s
    end

    def response_description
        s = "%s | %.3f sec\n".light_magenta % [response.description.chomp, time_used]

        max_key_size = response.headers.max_by do |k, v|
            k.size
        end[0].size

        s << response.headers.map do |k, v|
            "%#{max_key_size}s".green % k + ': ' + v.green + "\n"
        end.join

        s << response.to_s if response.headers[:content_type] == 'application/xml'
        return s
    end

    def get_authorization
        sign_time           = "#{Time.now.to_i - 3600};#{Time.now.to_i + 3600}"
        sign_key            = OpenSSL::HMAC.hexdigest('sha1', Conf.secret_key, sign_time)
        http_string         = get_http_string
        sha1ed_http_string  = Digest::SHA1.hexdigest http_string
        string_to_sign      = "sha1\n#{sign_time}\n#{sha1ed_http_string}\n"
        signature           = OpenSSL::HMAC.hexdigest('sha1', sign_key, string_to_sign)

        {
            'q-sign-algorithm'  => 'sha1',
            'q-ak'              => Conf.secret_id,
            'q-sign-time'       => sign_time,
            'q-key-time'        => sign_time,
            'q-header-list'     => get_header_list,
            'q-url-param-list'  => get_param_list,
            'q-signature'       => signature
        }.map do |k, v|
            "#{k}=#{v}"
        end.join('&')
    end

    def get_http_string
        http_string  = http_method + "\n"
        http_string += uri + "\n"
        http_string += get_params + "\n"
        http_string += get_headers + "\n"
    end

    # NOTE: 暂不需要
    def get_params
        ''
    end

    # NOTE: 暂不需要
    def get_param_list
        ''
    end

    def get_headers
        return '' if !headers

        headers.map do |k, v|
            "#{k.downcase}=#{CGI::escape(v)}"
        end.sort.join('&')
    end

    def get_header_list
        return '' if !headers

        headers.map do |k, v|
            k.downcase
        end.sort.join(';')
    end
end

################################################################
# main

if __FILE__ == $0
    def test_put
        CosRequest.put '/aimee/test.txt', body: 'abc123'
    end

    def test_get
        CosRequest.get '/aimee/test.txt'
    end

    test_put
    test_get
end
