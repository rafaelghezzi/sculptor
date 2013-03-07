/*
 * Copyright 2007 The Fornax Project Team, including the original
 * author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.sculptor.generator.template.repository

import org.sculptor.generator.template.common.ExceptionTmpl
import sculptormetamodel.Parameter
import sculptormetamodel.RepositoryOperation

import static org.sculptor.generator.ext.Properties.*
import static org.sculptor.generator.template.repository.AccessObjectTmpl.*

import static extension org.sculptor.generator.ext.Helper.*
import static extension org.sculptor.generator.util.HelperBase.*

class AccessObjectTmpl {

def static String command(RepositoryOperation it) {
	'''
		�commandInterface(it)�
		�commandImpl(it)�
	'''
}


def static String commandInterface(RepositoryOperation it) {
	fileOutput(javaFileName(getAccessapiPackage(repository.aggregateRoot.module) + "." + getAccessObjectName()), '''
	�javaHeader()�
	package �getAccessapiPackage(repository.aggregateRoot.module)�;

	�IF it.formatJavaDoc() == "" �
		/**
		 * <p>
		 * Access object for �repository.name�.�name�.
		 * </p>
		 * <p>
		 * Command design pattern. Set input parameters with the
		 * setter methods. {@link #execute Execute}
		 * the command�IF it.getTypeName() != "void"� and retrieve the {@link #getResult result}�ENDIF�.
		 * </p>
		 *
		 */
	�ELSE�
		�it.formatJavaDoc()�
	�ENDIF �
	public interface �getAccessObjectName()� �IF it.getAccessObjectInterfaceExtends() != ''� extends �it.getAccessObjectInterfaceExtends()� �ENDIF�{

		�it.parameters.filter(e|!e.isPagingParameter()).map[interfaceParameterSetter(it)]�

		void execute() �ExceptionTmpl::throwsDecl(it)�;

		�IF it.getTypeName() != "void"�
		/**
			* The result of the command.
			*/
		�it.getAccessObjectResultTypeName()� getResult();
		�ENDIF�

	}
	'''
	)
}

def static String interfaceParameterSetter(Parameter it) {
	'''

		void set�name.toFirstUpper()�(�it.getTypeName()� �name�);
	'''
}

def static String commandImpl(RepositoryOperation it) {
	'''
		�commandImplBase(it)�
		�commandImplSubclass(it)�
	'''
}

def static String commandImplBase(RepositoryOperation it) {
	fileOutput(javaFileName(getAccessimplPackage(repository.aggregateRoot.module) + "." + getAccessObjectName() + "ImplBase"), '''
	�javaHeader()�
	package �getAccessimplPackage(repository.aggregateRoot.module)�;

	/**
	 * <p>
	 * Generated base class for implementation of Access object for �repository.name�.�name�.
	 * </p>
	 * <p>
	 * Command design pattern.
	 * </p>
	 *
	 */
	public abstract class �getAccessObjectName()�ImplBase extends �it.getAccessBase()�
	implements �getAccessapiPackage(repository.aggregateRoot.module)�.�getAccessObjectName()� {

	�IF jpa()�
		�IF isSpringToBeGenerated() �
			�IF isJpaProviderHibernate()�
				�jpaHibernateTemplate(it)�
			�ENDIF�
			�jpaTemplate(it)�
		�ENDIF�
	�ENDIF�
	
		�it.parameters.filter(e|!e.isPagingParameter()).map[parameterAttribute(it)]�

		�IF it.getTypeName() != "void"�
		private �it.getAccessObjectResultTypeName()� result;
		�ENDIF�

		�it.parameters.filter(e|!e.isPagingParameter()).map[parameterAccessors(it)]�

		�IF it.hasPagingParameter()�
			�pageableProperties(it)�
		�ENDIF�

		�IF !it.exceptions.isEmpty�
		public void execute() �ExceptionTmpl::throwsDecl(it)� {
			try {
				super.execute();
			�FOR exc : it.exceptions�
			} catch (�exc� e) {
				throw e;
			�ENDFOR�
			} catch (�applicationExceptionClass()� e) {
				// other ApplicationException not expected, wrap it in a RuntimeException
				throw new RuntimeException(e);
			}
		}
		�ENDIF�

		�IF it.getTypeName() != "void"�
		/**
			* The result of the command.
			*/
		public �it.getAccessObjectResultTypeName()� getResult() {
			return this.result;
		}

		protected void setResult(�it.getAccessObjectResultTypeName()� result) {
			this.result = result;
		}
		�ENDIF�

	}
	'''
	)
}

def static String pageableProperties(RepositoryOperation it) {
	'''
		private int firstResult = -1;
		private int maxResult = 0;

		protected int getFirstResult() {
			return firstResult;
		}

		public void setFirstResult(int firstResult) {
			this.firstResult = firstResult;
		}

		protected int getMaxResult() {
			return maxResult;
		}

		public void setMaxResult(int maxResult) {
			this.maxResult = maxResult;
		}
	'''
}

def static String jpaTemplate(RepositoryOperation it) {
	'''
		private org.springframework.orm.jpa.JpaTemplate jpaTemplate;
		
		/**
			* creates the JpaTemplate to be used in AccessObject for convenience
			*
			* @return Spring JpaTemplate
			*/
		protected org.springframework.orm.jpa.JpaTemplate getJpaTemplate() {
			if (jpaTemplate == null) {
				jpaTemplate = new org.springframework.orm.jpa.JpaTemplate(getEntityManager());
			}
			return jpaTemplate;
		}
	'''
}

def static String jpaHibernateTemplate(RepositoryOperation it) {
	'''
		private org.springframework.orm.hibernate3.HibernateTemplate hibernateTemplate;
		
		/**
			* creates the HibernateTemplate to be used in AccessObject for convenience
			*
			* @return Spring HibernateTemplate
			*/
		protected org.springframework.orm.hibernate3.HibernateTemplate getHibernateTemplate() {
			if (hibernateTemplate == null) {
				hibernateTemplate = new org.springframework.orm.hibernate3.HibernateTemplate(
				    �fw("accessimpl.jpahibernate.HibernateSessionHelper")�.getHibernateSession(getEntityManager()).getSessionFactory());
			}
			return hibernateTemplate;
		}
	'''
}

def static String commandImplSubclass(RepositoryOperation it) {
	fileOutput(javaFileName(getAccessimplPackage(repository.aggregateRoot.module) + "." + getAccessObjectName() + "Impl"), 'TO_SRC', '''
	�javaHeader()�
	package �getAccessimplPackage(repository.aggregateRoot.module)�;

	/**
	 * Implementation of Access object for �repository.name�.�name�.
	 *
	 */
	public class �getAccessObjectName()�Impl ^extends �getAccessObjectName()�ImplBase {

			�performExecute(it)�

	}
	'''
	)
}

def static String performExecute(RepositoryOperation it) {
	'''
	public void performExecute() �ExceptionTmpl::throwsDecl(it)� {
			// TODO Auto-generated method stub
			throw new UnsupportedOperationException("�getAccessObjectName()�Impl not implemented");
		}
	'''
}

def static String parameterAttribute(Parameter it) {
	'''
		private �it.getTypeName()� �name�;
	'''
}

def static String parameterAccessors(Parameter it) {
	'''
		�parameterGetter(it)�
		�parameterSetter(it)�
	'''
}

def static String parameterGetter(Parameter it) {
	'''
		public �it.getTypeName()� get�name.toFirstUpper()�() {
			return �name�;
		};
	'''
}

def static String parameterSetter(Parameter it) {
	'''
		public void set�name.toFirstUpper()�(�it.getTypeName()� �name�) {
			this.�name� = �name�;
		};
	'''
}

}