from flask import Flask

app = Flask(__name__)

@app.route("/")
def home():
    return "Hello Docker! Welcome to Broadway Infosys."

@app.route("/about")
def about():
    return "This is a Docker II practical lab."

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)