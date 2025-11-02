#!/usr/bin/env node
/**
 * Script to initialize missing Role documents in MongoDB
 * Run this to fix login issues caused by missing Role documents
 */

const path = require('path');
require('module-alias')({ base: path.resolve(__dirname, 'api') });
const mongoose = require('mongoose');
const { Role } = require('@librechat/data-schemas').createModels(mongoose);
const { SystemRoles, roleDefaults } = require('librechat-data-provider');
const connect = require('./config/connect');

async function fixRoles() {
  try {
    console.log('🔌 Verbinde mit MongoDB...');
    const mongoose = require('mongoose');
    const { createModels } = require('@librechat/data-schemas');
    createModels(mongoose);
    
    const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/LibreChat';
    await mongoose.connect(MONGO_URI);
    console.log('✅ Verbunden mit MongoDB\n');

    console.log('📝 Initialisiere Role-Dokumente...\n');

    for (const roleName of [SystemRoles.ADMIN, SystemRoles.USER]) {
      let role = await Role.findOne({ name: roleName });
      const defaultPerms = roleDefaults[roleName].permissions;

      if (!role) {
        console.log(`  ➕ Erstelle ${roleName} Role...`);
        role = new Role(roleDefaults[roleName]);
      } else {
        console.log(`  🔄 Aktualisiere ${roleName} Role...`);
        const permissions = role.toObject()?.permissions ?? {};
        role.permissions = role.permissions || {};
        for (const permType of Object.keys(defaultPerms)) {
          if (permissions[permType] == null || Object.keys(permissions[permType]).length === 0) {
            role.permissions[permType] = defaultPerms[permType];
          }
        }
      }
      await role.save();
      console.log(`  ✅ ${roleName} Role erfolgreich\n`);
    }

    console.log('✅ Alle Roles erfolgreich initialisiert!');
    console.log('\n📊 Rollen-Übersicht:');
    const roles = await Role.find({}).select('name permissions').lean();
    roles.forEach(role => {
      console.log(`  - ${role.name}: ${Object.keys(role.permissions).length} Permission-Typen`);
    });

    process.exit(0);
  } catch (err) {
    console.error('❌ Fehler beim Initialisieren der Roles:', err);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
  }
}

fixRoles();

