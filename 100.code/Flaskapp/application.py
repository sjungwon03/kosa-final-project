"Demo Flask application"
import json
import os
import subprocess
import requests

from flask import Flask, render_template, render_template_string, url_for, redirect, flash, g, Response
from flask_wtf import FlaskForm
from flask_wtf.file import FileField
from wtforms import StringField, HiddenField, validators
import boto3

import config
import util

def get_instance_document():
    if os.environ.get("SKIP_INSTANCE_METADATA", "true").lower() == "true":
        return { "availabilityZone" : "kubernetes",  "instanceId" : "pod" }

    try:
        r = requests.get("http://169.254.169.254/latest/dynamic/instance-identity/document", timeout=1)
        if r.status_code == 401:
            token=(
                requests.put(
                    "http://169.254.169.254/latest/api/token", 
                    headers={'X-aws-ec2-metadata-token-ttl-seconds': '21600'}, 
                    verify=False, timeout=1
                )
            ).text
            r = requests.get(
                "http://169.254.169.254/latest/dynamic/instance-identity/document",
                headers={'X-aws-ec2-metadata-token': token}, timeout=1
            )
        r.raise_for_status()
        return r.json()
    except:
        print(" * Instance metadata not available")
        return { "availabilityZone" : "us-fake-1a",  "instanceId" : "i-fakeabc" }


if "DYNAMO_MODE" in os.environ:
    import database_dynamo as database
else:
    import database

application = Flask(__name__)
application.secret_key = config.FLASK_SECRET

doc = get_instance_document()
availablity_zone = doc["availabilityZone"]
instance_id = doc["instanceId"]

badges = {
    "apple": "Mac User",
    "windows": "Windows User",
    "linux": "Linux User",
    "camera-video": "Digital Content Star",
    "trophy": "Employee of the Month",
    "camera": "Photographer",
    "airplane": "Frequent Flier",
    "paperclip": "Paperclip Fan",
    "cup-hot": "Coffee Snob",
    "controller": "Gamer",
    "bug": "Bugfixer",
    "umbrella": "Seattle Fan",
}

def get_s3_client():
    "Build an S3 client using the configured endpoint when provided"
    kwargs = {}
    if config.S3_ENDPOINT_URL:
        kwargs["endpoint_url"] = config.S3_ENDPOINT_URL
    return boto3.client('s3', **kwargs)

def set_photo_url(employee):
    "Attach an app-served photo URL for templates"
    if employee and "object_key" in employee and employee["object_key"]:
        employee["photo_url"] = url_for("photo", employee_id=employee["id"])

### FlaskForm set up
class EmployeeForm(FlaskForm):
    """flask_wtf form class"""
    employee_id = HiddenField()
    photo = FileField('image')
    full_name = StringField(u'Full Name', [validators.InputRequired()])
    location = StringField(u'Location', [validators.InputRequired()])
    job_title = StringField(u'Job Title', [validators.InputRequired()])
    badges = HiddenField(u'Badges')

@application.before_request
def before_request():
    "Set up globals referenced in jinja templates"
    g.availablity_zone = availablity_zone
    g.instance_id = instance_id

@application.route("/")
def home():
    "Home screen"
    try:
        employees = database.list_employees()
    except Exception as exc:
        print(f" * Database unavailable: {exc}")
        employees = []

    if not employees:
        return render_template_string("""        
        {% extends "main.html" %}
        {% block head %}
        <div class="employee-toolbar">
          <div class="employee-toolbar__title">
            Team Directory
            <span>Manage people, roles, and profile photos</span>
          </div>
          <a class="btn btn-primary" href="{{ url_for('add') }}"><i class="bi bi-plus-lg"></i> Add Employee</a>
        </div>
        {% endblock %}
        {% block body %}
        <div class="empty-state">
          <i class="bi bi-address-book"></i>
          <h3>No employees yet</h3>
          <p>Add the first employee to start building the directory.</p>
        </div>
        {% endblock %}
        """)
    else:
        for employee in employees:
            set_photo_url(employee)

    return render_template_string("""
        {% extends "main.html" %}
        {% block head %}
        <div class="employee-toolbar">
          <div class="employee-toolbar__title">
            Team Directory
            <span>{{ employees|length }} employee{% if employees|length != 1 %}s{% endif %} in the directory</span>
          </div>
          <div class="toolbar-actions">
            <label class="search-box">
              <i class="bi bi-search"></i>
              <input id="employeeSearch" type="search" placeholder="Search people...">
            </label>
            <a class="btn btn-primary" href="{{ url_for('add') }}"><i class="bi bi-plus-lg"></i> Add Employee</a>
          </div>
        </div>
        {% endblock %}
        {% block body %}
            <div class="directory-summary">
              <div>
                <span class="summary-label">Directory status</span>
                <strong>Live</strong>
              </div>
              <div>
                <span class="summary-label">Profiles</span>
                <strong>{{ employees|length }}</strong>
              </div>
              <div>
                <span class="summary-label">Storage</span>
                <strong>S3</strong>
              </div>
            </div>
            <div class="employee-list">
            {% for employee in employees %}
                <article class="employee-row" data-search="{{ employee.full_name }} {{ employee.job_title }} {{ employee.location }} {{ employee.badges }}">
                  {% if employee.photo_url %}
                  <img class="employee-photo" src="{{employee.photo_url}}" alt="{{employee.full_name}}">
                  {% else %}
                  <div class="employee-photo photo-placeholder"><i class="bi bi-person-fill"></i></div>
                  {% endif %}
                  <div class="employee-info">
                    <h3 class="employee-name"><a href="{{ url_for('view', employee_id=employee.id) }}">{{employee.full_name}}</a></h3>
                    <div class="employee-meta"><i class="bi bi-briefcase"></i> {{employee.job_title}} · <i class="bi bi-geo-alt"></i> {{employee.location}}</div>
                    <div class="employee-badges">
                  {% for badge in badges %}
                  {% if badge in employee['badges'] %}
                  <span class="badge-pill"><i class="bi bi-{{badge}}"></i> {{badges[badge]}}</span>
                  {% endif %}
                  {% endfor %}
                    </div>
                  </div>
                  <div class="row-actions">
                    <a class="icon-button" href="{{ url_for('view', employee_id=employee.id) }}" title="View"><i class="bi bi-eye"></i></a>
                    <a class="icon-button" href="{{ url_for('edit', employee_id=employee.id) }}" title="Edit"><i class="bi bi-pencil"></i></a>
                    <a class="icon-button icon-button--danger" href="{{ url_for('delete', employee_id=employee.id) }}" title="Delete"><i class="bi bi-trash"></i></a>
                  </div>
                </article>
            {% endfor %}
            </div>

        {% endblock %}
    """, employees=employees, badges=badges)

@application.route("/add")
def add():
    "Add an employee"
    form = EmployeeForm()
    return render_template("view-edit.html", form=form, badges=badges)

@application.route("/edit/<employee_id>")
def edit(employee_id):
    "Edit an employee"
    employee = database.load_employee(employee_id)
    signed_url = None
    if "object_key" in employee and employee["object_key"]:
        signed_url = url_for("photo", employee_id=employee["id"])

    form = EmployeeForm()
    form.employee_id.data = employee['id']
    form.full_name.data = employee['full_name']
    form.location.data = employee['location']
    form.job_title.data = employee['job_title']
    if 'badges' in employee:
        form.badges.data = employee['badges']

    return render_template("view-edit.html", form=form, badges=badges, signed_url=signed_url)

@application.route("/save", methods=['POST'])
def save():
    "Save an employee"
    form = EmployeeForm()
    s3_client = get_s3_client()
    key = None
    if form.validate_on_submit():
        if form.photo.data:
            image_bytes = util.resize_image(form.photo.data, (120, 160))
            if image_bytes:
                try:
                    # save the image to s3
                    prefix = "employee_pic/"
                    key = prefix + util.random_hex_bytes(8) + '.png'
                    s3_client.put_object(
                        Bucket=config.PHOTOS_BUCKET,
                        Key=key,
                        Body=image_bytes,
                        ContentType='image/png'
                    )
                except Exception as exc:
                    print(f" * Failed to upload employee photo to S3: {exc}")
                    flash("Photo upload failed. Employee information was saved without a photo.")
        
        if form.employee_id.data:
            database.update_employee(
                form.employee_id.data,
                key,
                form.full_name.data,
                form.location.data,
                form.job_title.data,
                form.badges.data)
        else:
            database.add_employee(
                key,
                form.full_name.data,
                form.location.data,
                form.job_title.data,
                form.badges.data)
        flash("Saved!")
        return redirect(url_for("home"))
    else:
        return "Form failed validate"

@application.route("/employee/<employee_id>")
def view(employee_id):
    "View an employee"
    employee = database.load_employee(employee_id)
    set_photo_url(employee)
    form = EmployeeForm()

    return render_template_string("""
        {% extends "main.html" %}
        {% block head %}
        <div class="employee-toolbar">
          <div class="employee-toolbar__title">
            {{employee.full_name}}
            <span>Employee profile</span>
          </div>
          <div>
            <a class="btn btn-ghost" href="{{ url_for('home') }}"><i class="bi bi-arrow-left"></i> Home</a>
            <a class="btn btn-primary" href="{{ url_for("edit", employee_id=employee.id) }}"><i class="bi bi-pencil"></i> Edit</a>
          </div>
        </div>
        {% endblock %}
        {% block body %}
  <div class="profile-layout">
    <div>
        {% if employee.photo_url %}
        <img class="profile-photo" alt="{{ employee.full_name }}" src="{{ employee.photo_url }}" />
        {% else %}
        <div class="profile-photo photo-placeholder"><i class="bi bi-person-fill"></i></div>
        {% endif %}
    </div>

    <div class="detail-list">
      <div class="detail-item">
        <span class="detail-label"><i class="bi bi-geo-alt"></i> Location</span>
        <div class="detail-value">{{employee.location}}</div>
      </div>
      <div class="detail-item">
        <span class="detail-label"><i class="bi bi-briefcase"></i> Job Title</span>
        <div class="detail-value">{{employee.job_title}}</div>
      </div>
      <div class="detail-item">
        <span class="detail-label"><i class="bi bi-award"></i> Badges</span>
        <div class="detail-value">
      {% for badge in badges %}
        {% if badge in employee['badges'] %}
        <span class="badge-pill"><i class="bi bi-{{badge}}"></i> {{badges[badge]}}</span>
        {% endif %}
      {% endfor %}
        </div>
      </div>
    </div>
  </div>
        {% endblock %}
    """, form=form, employee=employee, badges=badges)

@application.route("/photo/<employee_id>")
def photo(employee_id):
    "Serve an employee photo from S3 through the app"
    employee = database.load_employee(employee_id)
    if not employee or not employee.get("object_key"):
        return ("Not found", 404)

    try:
        s3_object = get_s3_client().get_object(
            Bucket=config.PHOTOS_BUCKET,
            Key=employee["object_key"],
        )
        return Response(
            s3_object["Body"].read(),
            mimetype=s3_object.get("ContentType", "image/png"),
        )
    except Exception as exc:
        print(f" * Failed to load employee photo from S3: {exc}")
        return ("Not found", 404)

@application.route("/delete/<employee_id>")
def delete(employee_id):
    "delete employee route"
    database.delete_employee(employee_id)
    flash("Deleted!")
    return redirect(url_for("home"))

@application.route("/info")
def info():
    "Webserver info route"
    return {
        "status": "ok",
        "instance_id": g.instance_id,
        "availability_zone": g.availablity_zone,
    }

@application.route("/info/stress_cpu/<seconds>")
def stress(seconds):
    "Max out the CPU"
    flash("Stressing CPU")
    subprocess.Popen(["stress", "--cpu", "8", "--timeout", seconds])
    return redirect(url_for("info"))

if __name__ == "__main__":
    application.run(debug=True)
