const crypto = require('crypto');
const nodemailer = require('nodemailer');
const config = require('../config');
const logger = require('./logger');

const generateOtp = () => crypto.randomInt(100000, 999999).toString();

let transporter = null;

const getTransporter = () => {
  if (transporter) return transporter;

  transporter = nodemailer.createTransport({
    host: config.smtpHost,
    port: config.smtpPort,
    secure: config.smtpPort === 465,
    auth: {
      user: config.smtpUser,
      pass: config.smtpPass,
    },
  });

  return transporter;
};

const sendOtpEmail = async (email, code) => {
  if (config.nodeEnv === 'development' && !config.smtpUser) {
    logger.info(`[DEV] OTP for ${email}: ${code}`);
    return;
  }

  const mailOptions = {
    from: `"Reverse Match" <${config.smtpUser}>`,
    to: email,
    subject: 'Your Verification Code',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 400px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #e91e63;">Reverse Match</h2>
        <p>Your verification code is:</p>
        <h1 style="letter-spacing: 8px; color: #333; text-align: center; padding: 20px; background: #f5f5f5; border-radius: 8px;">${code}</h1>
        <p style="color: #666; font-size: 14px;">This code expires in ${config.otpExpiryMinutes} minutes.</p>
      </div>
    `,
  };

  await getTransporter().sendMail(mailOptions);
};

module.exports = { generateOtp, sendOtpEmail };
