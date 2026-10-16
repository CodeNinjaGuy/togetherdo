/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Mailversand über Amazon SES (SMTP, STARTTLS) – nach dem Muster von SeeBubble.
//
// Region eu-north-1, Domain seebubble.me. Die SMTP-Zugangsdaten kommen nur aus
// den Firebase-Secrets SES_SMTP_USER und SES_SMTP_PASSWORD, nie aus dem Code
// und nie ins Log. Im Log stehen nie Empfängeradressen, nur die Mail-Art.
//
// Für Tests lässt sich der Transport ersetzen (`setzeTransportFuerTests`);
// im Emulator ohne Test-Transport wird nur protokolliert.

import { defineSecret } from 'firebase-functions/params';
import * as nodemailer from 'nodemailer';

export const sesSmtpUser = defineSecret('SES_SMTP_USER');
export const sesSmtpPassword = defineSecret('SES_SMTP_PASSWORD');
export const sesSecrets = [sesSmtpUser, sesSmtpPassword];

export const SES_HOST = 'email-smtp.eu-north-1.amazonaws.com';
export const SES_PORT = 587;
export const ABSENDER = 'ToGetherDo <noreply@seebubble.me>';

export interface MailAnhang {
  dateiname: string;
  inhalt: string | Buffer;
  typ: string;
}

export interface Mail {
  an: string;
  betreff: string;
  html: string;
  text: string;
  anhaenge?: MailAnhang[];
  /** Kennzeichnung fürs Log, z. B. „erinnerung“ – nie Adressen oder Inhalte. */
  art: string;
}

export type MailSender = (mail: Mail) => Promise<void>;

/** Das, was wir von nodemailer brauchen – so bleibt ein Fake im Test klein. */
export interface MailTransport {
  sendMail(optionen: nodemailer.SendMailOptions): Promise<{ messageId?: string }>;
}

let testTransport: MailTransport | null = null;

/** Nur für Tests: Transport ersetzen (null = wieder normal). */
export function setzeTransportFuerTests(transport: MailTransport | null): void {
  testTransport = transport;
}

function secretWert(secret: { value(): string }, envName: string): string {
  try {
    const v = secret.value();
    if (v) return v.trim();
  } catch {
    // Secret nicht gebunden (z. B. außerhalb einer Function) – Rückfall auf env.
  }
  return (process.env[envName] ?? '').trim();
}

let transport: nodemailer.Transporter | null = null;
let transportSchluessel = '';

function holeTransport(user: string, pass: string): nodemailer.Transporter {
  const schluessel = `${user}:${pass.length}`;
  if (!transport || transportSchluessel !== schluessel) {
    transport = nodemailer.createTransport({
      host: SES_HOST,
      port: SES_PORT,
      secure: false,
      requireTLS: true,
      auth: { user, pass },
      tls: { minVersion: 'TLSv1.2', servername: SES_HOST },
    });
    transportSchluessel = schluessel;
  }
  return transport;
}

/** nodemailer-Optionen aus unserer Mail (ohne Reply-To). */
export function mailOptionen(mail: Mail): nodemailer.SendMailOptions {
  return {
    from: ABSENDER,
    to: mail.an,
    subject: mail.betreff,
    html: mail.html,
    text: mail.text,
    attachments: mail.anhaenge?.map((a) => ({ filename: a.dateiname, content: a.inhalt, contentType: a.typ })),
    headers: { 'X-ToGetherDo-Mail': mail.art },
  };
}

/**
 * Schickt eine Mail über SES. Wirft bei fehlender Konfiguration oder
 * Versandfehler. Im Emulator ohne Test-Transport wird nur protokolliert.
 */
export async function sendeMail(mail: Mail): Promise<void> {
  if (testTransport) {
    await testTransport.sendMail(mailOptionen(mail));
    return;
  }
  if (process.env.FUNCTIONS_EMULATOR === 'true') {
    console.log(`[Mail gestubbt] art=${mail.art}`);
    return;
  }
  const user = secretWert(sesSmtpUser, 'SES_SMTP_USER');
  const pass = secretWert(sesSmtpPassword, 'SES_SMTP_PASSWORD');
  if (!user || !pass) throw new Error('SES_SMTP_USER/SES_SMTP_PASSWORD fehlen');
  const info = await holeTransport(user, pass).sendMail(mailOptionen(mail));
  console.log(`Mail über SES verschickt: art=${mail.art} id=${info.messageId}`);
}
