use core::panic;
use std::{env, fs, path::Path};

use actix_web::{
    http::{StatusCode, Version},
    web::{self, Data},
    App, HttpRequest, HttpResponse, HttpServer,
};
use anyhow::{bail, Result};
use log::{error, info};
use modsecurity::{ModSecurity, Rules};

const SETUP_CONF: &'static str = "setup.conf";

async fn default(req: HttpRequest, ms: Data<ModSecurity>, rules: Data<Rules>) -> HttpResponse {
    match analyze(&req, ms, rules) {
        Ok(status) => HttpResponse::Ok().status(status).finish(),
        Err(error) => {
            error!("Failed to analyze request {} => {error}", req.path());
            return HttpResponse::InternalServerError().finish();
        }
    }
}

fn analyze(req: &HttpRequest, ms: Data<ModSecurity>, rules: Data<Rules>) -> Result<StatusCode> {
    let mut transaction = ms.transaction_builder().with_rules(&rules).build()?;

    let version = match req.head().version {
        Version::HTTP_09 => "0.9",
        Version::HTTP_10 => "1.0",
        Version::HTTP_11 => "1.1",
        Version::HTTP_2 => "2",
        Version::HTTP_3 => "3",
        _ => {
            bail!("Unknown http version")
        }
    };

    for (name, value) in req.headers() {
        let header_name = name.as_str();
        let header_value = match value.to_str() {
            Ok(header_value) => header_value,
            Err(error) => {
                error!("Failed to parse header {} => {}", header_name, error);
                continue;
            }
        };

        transaction.add_request_header(header_name, header_value)?;
    }

    transaction.process_uri(req.path(), req.method().as_str(), version)?;
    transaction.process_request_headers()?;
    //transaction.process_logging()?;

    let status = match transaction.intervention() {
        Some(intervention) => intervention.status() as u16,
        None => 200,
    };
    let status_code = StatusCode::from_u16(status)?;

    Ok(status_code)
}

fn get_modsecurity_rules(path: &str) -> Result<Rules> {
    let mut rules = Rules::new();
    let modsecurity_path = Path::new(path);

    let setup_conf_path = modsecurity_path.join(SETUP_CONF);
    let setup_conf_string = fs::read_to_string(setup_conf_path)?;
    if setup_conf_string.is_empty() {
        bail!("Empty setup.conf content")
    }
    rules.add_plain(&setup_conf_string)?;

    Ok(rules)
}

#[actix_web::main]
async fn main() -> Result<()> {
    env_logger::init();

    let ip = env::var("HOST").unwrap_or("127.0.0.1".to_owned());
    let port: u16 = match env::var("PORT").unwrap_or("8080".to_owned()).parse() {
        Ok(port) => port,
        Err(error) => bail!("Failed to parse port => {error}"),
    };
    let modsecurity_conf_path =
        env::var("MODSECURITY_CONF_PATH").unwrap_or("/etc/modsecurity.d".to_owned());

    info!("Starting");

    match HttpServer::new(move || {
        let rules = match get_modsecurity_rules(&modsecurity_conf_path) {
            Ok(rules) => rules,
            Err(error) => panic!("Failed to get modsecurity rules => {error}"),
        };

        App::new()
            .app_data(web::Data::new(ModSecurity::default()))
            .app_data(web::Data::new(rules))
            .default_service(web::to(default))
    })
    .bind((ip, port))?
    .run()
    .await
    {
        Ok(_) => {}
        Err(error) => {
            bail!("An error occured when starting server => {error}")
        }
    }

    Ok(())
}
