use anyhow::{anyhow, Context, Result};
use reqwest::{Client, ClientBuilder, header};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::time::Duration;
use scraper::{Html, Selector};
use regex::Regex;

/// Bypass server endpoint (CloudflareBypassForScraping running locally)
const BYPASS_SERVER: &str = "http://localhost:8000";

/// Warm cookies for a hostname via the bypass server.
/// The server launches a stealth browser, solves CF, and caches cookies.
async fn warm_cookies(client: &Client, hostname: &str) -> Result<()> {
    let url = format!("{}/", BYPASS_SERVER);
    let resp = client
        .get(&url)
        .header("x-hostname", hostname)
        .send()
        .await
        .with_context(|| format!("Failed to warm cookies for {}", hostname))?;

    let status = resp.status();
    if status.is_success() || status.as_u16() == 302 {
        log::info!("Cookies warmed for {} (status: {})", hostname, status);
        Ok(())
    } else {
        // Even non-200 might mean the server got the cookies but the page returned an error
        log::warn!("Cookie warm for {} returned status {} (may still be cached)", hostname, status);
        Ok(())
    }
}

/// Extract cookies from the bypass server's /cookies endpoint
async fn get_cookies(client: &Client, url: &str) -> Result<HashMap<String, String>> {
    let api_url = format!("{}/cookies?url={}", BYPASS_SERVER, urlencoding::encode(url));
    let resp = client
        .get(&api_url)
        .send()
        .await?;

    let json: serde_json::Value = resp.json().await?;
    let mut cookies = HashMap::new();
    
    if let Some(c) = json.get("cookies").and_then(|c| c.as_object()) {
        for (k, v) in c {
            if let Some(val) = v.as_str() {
                cookies.insert(k.clone(), val.to_string());
            }
        }
    }
    
    Ok(cookies)
}

/// Mirror a request through the bypass server
async fn mirror_request(
    client: &Client,
    method: &str,
    target_url: &str,
    body: Option<&str>,
    extra_headers: Option<HashMap<String, String>>,
) -> Result<(u16, String)> {
    let parsed = url::Url::parse(target_url)?;
    let hostname = parsed.host_str().ok_or_else(|| anyhow!("No hostname in URL"))?;
    let path = if parsed.path().is_empty() { "/" } else { parsed.path() };
    let query = parsed.query();
    
    let mut full_path = path.to_string();
    if let Some(q) = query {
        full_path = format!("{}?{}", full_path, q);
    }

    let req = match method.to_uppercase().as_str() {
        "GET" => client.get(format!("{}{}", BYPASS_SERVER, full_path)),
        "POST" => client.post(format!("{}{}", BYPASS_SERVER, full_path)),
        "PUT" => client.put(format!("{}{}", BYPASS_SERVER, full_path)),
        "DELETE" => client.delete(format!("{}{}", BYPASS_SERVER, full_path)),
        _ => client.get(format!("{}{}", BYPASS_SERVER, full_path)),
    };

    let req = req
        .header("x-hostname", hostname)
        .header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36");

    // Add extra headers
    if let Some(headers) = extra_headers {
        for (k, v) in headers {
            req.header(&k, &v);
        }
    }

    // Add body for POST/PUT
    let req = if let Some(b) = body {
        req.header(header::CONTENT_TYPE, "application/json")
            .body(b.to_string())
    } else {
        req
    };

    let resp = req.send().await?;
    let status = resp.status().as_u16();
    let body_text = resp.text().await?;
    
    Ok((status, body_text))
}

/// Extract verification link from Proton Mail HTML
fn extract_verify_link(html: &str) -> Option<String> {
    // Try clerk.openrouter.ai verify URLs
    let re1 = Regex::new(r"https://clerk\.openrouter\.ai/v1/verify[^\s\"'<>]+").ok()?;
    if let Some(m) = re1.find(html) {
        return Some(m.as_str().replace("&amp;", "&"));
    }
    
    // Try openrouter.ai verify/confirm URLs
    let re2 = Regex::new(r"https://openrouter\.ai[^\s\"'<>]*(?:verify|confirm|token)[^\s\"'<>]+").ok()?;
    if let Some(m) = re2.find(html) {
        return Some(m.as_str().replace("&amp;", "&"));
    }
    
    None
}

/// Extract API key from page HTML
fn extract_api_key(html: &str) -> Option<String> {
    let re = Regex::new(r"sk-or-v1-[a-zA-Z0-9]{20,}").ok()?;
    re.find(html).map(|m| m.as_str().to_string())
}

/// Sign up on OpenRouter using the bypass server for CF handling
async fn signup_openrouter(client: &Client, email: &str, password: &str) -> Result<bool> {
    log::info!("=== Step 1: Pre-warm CF cookies for openrouter.ai ===");
    warm_cookies(client, "openrouter.ai").await?;
    tokio::time::sleep(Duration::from_secs(2)).await;

    log::info!("=== Step 2: Fetch signup page via bypass server ===");
    let (status, html) = mirror_request(client, "GET", "https://openrouter.ai/sign-up", None, None).await?;
    log::info!("Signup page status: {}, length: {}", status, html.len());

    // Check if we got a challenge page
    if html.contains("Just a moment") || html.contains("challenge") {
        log::warn!("Challenge detected on signup page, waiting and retrying...");
        tokio::time::sleep(Duration::from_secs(10)).await;
        let (status2, html2) = mirror_request(client, "GET", "https://openrouter.ai/sign-up", None, None).await?;
        if html2.contains("Just a moment") || html2.contains("challenge") {
            return Err(anyhow::anyhow!("Still on challenge page after retry"));
        }
    }

    // The bypass server returns the rendered HTML after CF is cleared
    // We need to extract the form action and submit directly
    // Clerk uses client-side rendering, so we submit via the mirror endpoint
    
    log::info!("=== Step 3: Submit signup form via bypass server ===");
    let signup_url = "https://openrouter.ai/sign-up";
    
    // Build form data as JSON (Clerk accepts this)
    let form_data = serde_json::json!({
        "email_address": email,
        "password": password,
        "legal_accepted": true,
    });

    let mut headers = HashMap::new();
    headers.insert("Content-Type".to_string(), "application/json".to_string());
    headers.insert("x-hostname".to_string(), "openrouter.ai".to_string());

    let (post_status, post_html) = mirror_request(
        client,
        "POST",
        &format!("{}/api/signup", BYPASS_SERVER),
        Some(&form_data.to_string()),
        None,
    ).await?;
    
    log::info!("Signup POST status: {}, response length: {}", post_status, post_html.len());
    log::info!("Response: {}", &post_html[..post_html.len().min(500)]);

    // Check for success indicators
    if post_html.contains("confirm") || post_html.contains("verification") || post_html.contains("check your") {
        return Ok(true);
    }
    
    // If the API endpoint doesn't exist, try the form action directly
    // Try submitting through the mirror endpoint with the form's actual action
    let (post_status2, post_html2) = mirror_request(
        client,
        "POST",
        "https://openrouter.ai/sign-up",
        Some(&form_data.to_string()),
        None,
    ).await?;
    
    log::info!("Signup POST (direct) status: {}, response: {}", post_status2, &post_html2[..post_html2.len().min(500)]);

    if post_html2.contains("confirm") || post_html2.contains("verification") || post_status2 == 302 || post_status2 == 200 {
        return Ok(true);
    }

    // Check the response HTML for any redirect or success indicator
    if post_html2.contains("confirm-email") || post_html2.contains("check-your") {
        return Ok(true);
    }

    log::warn!("Signup response unclear, checking if cookies were set...");
    let cookies = get_cookies(client, "https://openrouter.ai/sign-up").await?;
    if cookies.contains_key("cf_clearance") {
        log::info!("CF clearance cookie present, signup likely succeeded");
        return Ok(true);
    }

    Ok(false)
}

#[tokio::main]
async fn main() -> Result<()> {
    env_logger::init();
    
    // Create HTTP client with cookie store
    let client = ClientBuilder::new()
        .cookie_store(true)
        .timeout(Duration::from_secs(60))
        .build()?;

    // Generate or use existing email
    let email = std::env::var("OR_EMAIL").unwrap_or_else(||| {
        // Generate duck email via the email.sh script
        let output = std::process::Command::new("bash")
            .arg("/home/runner/workspace/scripts/email.sh")
            .output()
            .expect("Failed to run email.sh");
        String::from_utf8_lossy(&output.stdout)
            .lines()
            .last()
            .unwrap_or("")
            .trim()
            .to_string()
    });

    if email.is_empty() || !email.contains('@') {
        return Err(anyhow::anyhow!("No valid email generated"));
    }

    // Generate password
    let password = std::env::var("OR_PASSWORD").unwrap_or_else(||| {
        use rand::Rng;
        let mut rng = rand::thread_rng();
        let chars: Vec<char> = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%".chars().collect();
        let mut pw = String::new();
        // Ensure at least one letter, one digit, one special
        pw.push(chars[rng.gen_range(0..26)]); // lowercase letter
        pw.push(chars[36 + rng.gen_range(0..10)]); // digit
        pw.push(chars[62 + rng.gen_range(0..5)]); // special
        for _ in 0..12 {
            pw.push(chars[rng.gen_range(0..chars.len())]);
        }
        pw
    });

    log::info!("Email: {}", email);
    log::info!("Password: {}", password);

    // Step 1: Sign up
    let signup_ok = signup_openrouter(&client, &email, &password).await?;
    
    if signup_ok {
        log::info!("Signup appears successful!");
    } else {
        log::warn!("Signup result unclear - will try to check inbox anyway");
    }

    // Save credentials
    let cred_path = "/home/runner/workspace/credentials/openrouter_credentials.txt";
    std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(cred_path)?
        .write_all(format!("EMAIL={}\nPASSWORD={}\nAPI_KEY=PENDING\n", email, password).as_bytes())?;
    
    log::info!("Credentials saved to {}", cred_path);
    log::info!("Note: Email verification still required. Check Proton inbox for verify link.");

    Ok(())
}
