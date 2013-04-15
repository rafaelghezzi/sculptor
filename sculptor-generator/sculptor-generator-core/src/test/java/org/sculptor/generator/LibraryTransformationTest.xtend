package org.sculptor.generator

import com.google.inject.Guice
import com.google.inject.Injector
import com.google.inject.Provider
import org.eclipse.emf.common.util.EList
import org.eclipse.xtext.junit4.InjectWith
import org.eclipselabs.xtext.utils.unittesting.XtextRunner2
import org.eclipselabs.xtext.utils.unittesting.XtextTest
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.sculptor.dsl.SculptordslInjectorProvider
import org.sculptor.dsl.sculptordsl.DslApplication
import org.sculptor.dsl.sculptordsl.DslModel
import org.sculptor.generator.ext.DbHelper
import org.sculptor.generator.ext.Helper
import org.sculptor.generator.ext.Properties
import org.sculptor.generator.transform.DslTransformation
import org.sculptor.generator.transform.Transformation
import org.sculptor.generator.util.DbHelperBase
import sculptormetamodel.Application
import sculptormetamodel.Module
import sculptormetamodel.NamedElement

import static org.junit.Assert.*
import sculptormetamodel.Entity
import sculptormetamodel.Reference
import sculptormetamodel.ValueObject
import sculptormetamodel.Service
import sculptormetamodel.Attribute
import sculptormetamodel.Operation
import sculptormetamodel.ServiceOperation
import org.sculptor.generator.util.HelperBase
import org.sculptor.generator.mwe2.UniversalLoadModule

@RunWith(typeof(XtextRunner2))
@InjectWith(typeof(SculptordslInjectorProvider))
class LibraryTransformationTest extends XtextTest{
	
	extension Properties properties

	extension Helper helper

	extension HelperBase helperBase

	extension DbHelper dbHelper
	
	extension DbHelperBase dbHelperBase
	
	var DslApplication model
	var Provider<DslTransformation> dslTransformProvider
	var Provider<Transformation> transformationProvider
	var Application app
	
	protected static val SYSTEM_ATTRIBUTES = newImmutableSet("id", "uuid", "version",
		"createdBy", "createdDate", "updatedBy", "updatedDate", "lastUpdated", "lastUpdatedBy");
	
	
	@Before
	def void setupDslModel() {
		val uniLoadModule = new UniversalLoadModule(#[typeof(DslTransformation), typeof(Transformation)])
		val Injector injector = Guice::createInjector(uniLoadModule)
		properties = injector.getInstance(typeof(Properties))
		helper = injector.getInstance(typeof(Helper))
		helperBase = injector.getInstance(typeof(HelperBase))
		dbHelper = injector.getInstance(typeof(DbHelper))
		dbHelperBase = injector.getInstance(typeof(DbHelperBase))
		dslTransformProvider = injector.getProvider(typeof(DslTransformation))
		transformationProvider = injector.getProvider(typeof(Transformation))

		model = getDomainModel().app
		
		val dslTransformation = dslTransformProvider.get
		app = dslTransformation.transform(model)
		
		val transformation = transformationProvider.get
		app = transformation.modify(app)

	}

	def  getDomainModel() {
		
		testFileNoSerializer("library.btdesign", "library-person.btdesign")
		val dslModel = modelRoot as DslModel
		
		dslModel
		
        //val URI uri = URI::createURI(resourceRoot + "/" + "library.btdesign");
        //loadModel(resourceSet, uri, getRootObjectType(uri)) as DslModel;
	}
	
	
	def Module personModule() {		
		app.modules.namedElement('person')
    }

	// TODO: Move into helpers?
	def <T extends NamedElement> namedElement(EList<T> list, String toFindName) {
		list.findFirst[name == toFindName]
	}
	
	def Module mediaModule() {		
		app.modules.namedElement('media')
    }
    
    
    @Test
    def void assertApplication() {
        assertEquals("Library", app.getName());
    }



	def <NE extends NamedElement> void assertOneAndOnlyOne(EList<NE> listOfNamedElements, String... expectedNames) {
		val expectedNamesList = expectedNames.toList

		val actualNames = listOfNamedElements.map[ne|ne.name].filter[name | !SYSTEM_ATTRIBUTES.contains(name)].toList
				
		assertTrue("Expected: " + expectedNamesList + ", Actual: " + actualNames, actualNames.containsAll(expectedNamesList))
		assertTrue("Expected: " + expectedNamesList + ", Actual: " + actualNames, expectedNamesList.containsAll(actualNames))
		
	}

	@Test
    def void assertModules() {
        val modules = app.getModules();
        assertNotNull(modules);
        assertOneAndOnlyOne(modules, "media", "person");
    }

    @Test
    def void assertMediaModule() {
        val module = mediaModule;
        assertOneAndOnlyOne(module.domainObjects, "Library", "PhysicalMedia", "Media", "Book", "Movie",
                "Engagement", "MediaCharacter", "Genre", "Review", "Comment");
    }
    
    @Test
    def void assertPersonModule() {
        val module = personModule;
        assertOneAndOnlyOne(module.domainObjects, "Person", "Ssn", "Country", "Gender", "PersonName");
    }

    @Test
    def void assertPerson() {
        val person = personModule.domainObjects.namedElement("Person")
        assertOneAndOnlyOne(person.attributes, "birthDate")
        assertOneAndOnlyOne(person.references, "ssn", "name", "sex")
        val ssn =  person.references.namedElement("ssn")
        assertTrue(ssn.isNaturalKey())
        val ssnNumber = ssn.to.attributes.namedElement("number")
        assertTrue(ssnNumber.isNaturalKey())
        val ssnCountry = ssn.to.references.namedElement("country")
        assertTrue(ssnCountry.isNaturalKey())
        assertTrue(person.isGapClass)
        assertFalse(ssn.getTo().isGapClass)
    }
    
    /**
     * Bidirectional one-to-many
     */
    @Test
    def void assertReferenceToPhysicalMediaFromLibrary() {
        val library = mediaModule.domainObjects.namedElement("Library")
        val mediaRef = library.references.namedElement("media")
        assertFalse(dbHelperBase.isInverse(mediaRef))
        assertEquals("LIB_REF", mediaRef.oppositeForeignKeyName);
    }


    /**
     * Bidirectional many-to-one
     */
    @Test
    def void assertReferenceToLibraryFromPhysicalMedia() {
        val physicalMedia = mediaModule.domainObjects.namedElement("PhysicalMedia");
        val libraryRef = physicalMedia.references.namedElement("library");
        assertTrue(dbHelperBase.isInverse(libraryRef));
        
        assertEquals("LIB_REF", libraryRef.databaseColumn);
        assertEquals("LIB_REF", libraryRef.foreignKeyName);
        assertEquals("MEDIA", libraryRef.oppositeForeignKeyName);
    }
    /**
     * Bidirectional many-to-many
     */
    @Test
    def void assertReferenceToMediaFromPhysicalMedia() {
        val physicalMedia = mediaModule.domainObjects.namedElement("PhysicalMedia") as Entity
        
        val mediaRef = physicalMedia.references.namedElement("media") as Reference
        assertFalse(dbHelperBase.isInverse(mediaRef));

        assertEquals("PHMED_MED", mediaRef.manyToManyJoinTableName);
        assertEquals("MEDIA_REF", mediaRef.databaseColumn);
        assertEquals("MEDIA_REF", mediaRef.foreignKeyName);
        assertEquals("PHYSICALMEDIA", mediaRef.oppositeForeignKeyName);

        val manyToManyObject = mediaRef.createFictiveManyToManyObject();
        assertEquals("PHMED_MED", manyToManyObject.databaseTable);
        assertOneAndOnlyOne(manyToManyObject.references, "media", "physicalMedia");
        val manyToManyObjectMediaRef = manyToManyObject.references.namedElement("media") as Reference;
        assertEquals("MEDIA_REF", manyToManyObjectMediaRef.databaseColumn);
        val manyToManyObjectPhysicalMediaRef = manyToManyObject.references.namedElement("physicalMedia") as Reference;
        assertEquals("PHYSICALMEDIA", manyToManyObjectPhysicalMediaRef.databaseColumn);
    }

    /**
     * Bidirectional many-to-many
     */
    @Test
    def void assertReferenceToPhysicalMediaFromMedia() {
        val media = mediaModule.domainObjects.namedElement("Media") as Entity
        val physicalMediaRef = media.references.namedElement("physicalMedia") as Reference
        assertTrue(dbHelperBase.isInverse(physicalMediaRef))
        assertEquals("PHMED_MED", physicalMediaRef.getManyToManyJoinTableName())
        assertEquals("PHYSICALMEDIA", physicalMediaRef.databaseColumn)
        assertEquals("PHYSICALMEDIA", physicalMediaRef.foreignKeyName);
        assertEquals("MEDIA_REF", physicalMediaRef.oppositeForeignKeyName)

        val manyToManyObject = physicalMediaRef.createFictiveManyToManyObject()
        assertEquals("PHMED_MED", manyToManyObject.databaseTable)
        assertOneAndOnlyOne(manyToManyObject.references, "media", "physicalMedia")
        val manyToManyObjectMediaRef = manyToManyObject.references.namedElement("media") as Reference
        assertEquals("MEDIA_REF", manyToManyObjectMediaRef.databaseColumn)
        val manyToManyObjectPhysicalMediaRef = manyToManyObject.references.namedElement("physicalMedia") as Reference
        assertEquals("PHYSICALMEDIA", manyToManyObjectPhysicalMediaRef.databaseColumn);
    }


    /**
     * Unidirectional to-many with join table
     */
    @Test
    def void assertReferenceToPersonFromMediaCharacter() {
        val mediaCharacter = mediaModule.domainObjects.namedElement("MediaCharacter") as ValueObject
        val personRef = mediaCharacter.references.namedElement("playedBy") as Reference
        assertFalse(dbHelperBase.isInverse(personRef))
        assertEquals("MEDIA_CHR_PLAYEDBY", personRef.manyToManyJoinTableName)
        assertEquals("PLAYEDBY", personRef.databaseColumn)
        assertEquals("PLAYEDBY", personRef.foreignKeyName)
        assertEquals("MEDIA_CHR", personRef.oppositeForeignKeyName)

        val manyToManyObject = personRef.createFictiveManyToManyObject()
        assertEquals("MEDIA_CHR_PLAYEDBY", manyToManyObject.databaseTable)
        assertOneAndOnlyOne(manyToManyObject.references, "playedBy", "mediaCharacter")
        val manyToManyObjectPlayedByRef = manyToManyObject.references.namedElement("playedBy") as Reference
        assertEquals("PLAYEDBY", manyToManyObjectPlayedByRef.getDatabaseColumn());
        val manyToManyObjectMediaCharacterRef = manyToManyObject.references.namedElement("mediaCharacter") as Reference
        assertEquals("MEDIA_CHR", manyToManyObjectMediaCharacterRef.databaseColumn)
    }


    /**
     * Unidirectional to-many without join table
     */
    @Test
    def void assertReferenceToReviewFromMediaCharacter() {
        val mediaCharacter = mediaModule.domainObjects.namedElement("MediaCharacter") as ValueObject
        val reviewsRef = mediaCharacter.references.namedElement("reviews") as Reference;
        assertTrue(dbHelperBase.isInverse(reviewsRef))
        assertEquals("MEDIA_CHR", reviewsRef.databaseColumn)
        assertEquals("MEDIA_CHR", reviewsRef.oppositeForeignKeyName)
    }

    /**
     * Unidirectional to-many without join table, custom databaseColumn name.
     * List collection.
     */
    @Test
    def void assertReferenceToCommentFromMediaCharacter() {
        val mediaCharacter = mediaModule.domainObjects.namedElement("MediaCharacter") as ValueObject
        val commentsRef = mediaCharacter.references.namedElement("comments") as Reference
        assertTrue(dbHelperBase.isInverse(commentsRef))
        assertEquals("COMMENT_OF_CHARACTER", commentsRef.databaseColumn)
        assertEquals("COMMENT_OF_CHARACTER", commentsRef.oppositeForeignKeyName)
        assertEquals("COMMENT_OF_CHARACTER", commentsRef.databaseName)
        assertEquals("COMMENTS_INDEX", commentsRef.listIndexColumnName)
    }
    
    @Test
    def void assertLibraryService() {
        val service = mediaModule.services.namedElement("LibraryService") as Service
        assertTrue(service.isGapClass) // due to saveLibrary, someOtherMethod
                                       // and populate
        assertEquals("serviceHint", service.hint)
    }

    @Test
    def void assertLibraryRepository() {
        val library = mediaModule.domainObjects.namedElement("Library") as Entity
        assertEquals("entityHint", library.hint);
        val attrName = library.attributes.namedElement("name") as Attribute;
        assertEquals("attrHint", attrName.hint);
        val refMedia = library.references.namedElement("media") as Reference;
        assertEquals("referenceHint", refMedia.hint);

        val repository = library.repository;
        assertTrue(repository.isGapClass);
        assertEquals("repositoryHint", repository.hint);
        val operFindByQuery = repository.operations.namedElement("findByQuery") as Operation
        assertEquals("repoMethodHint", operFindByQuery.hint);
    }

    @Test
    def void assertMediaCharacterValueObject() {
        val mediaCharacterVO = mediaModule.domainObjects.namedElement("MediaCharacter") as ValueObject
        assertEquals("valueObjectHint", mediaCharacterVO.hint);
        val attrName = mediaCharacterVO.attributes.namedElement("name") as Attribute
        assertEquals("valueObjectAttrHint", attrName.hint);
        val refMedia = mediaCharacterVO.references.namedElement("existsInMedia") as Reference
        assertEquals("valueObjectRefHint", refMedia.hint)
    }

    @Test
    def void assertPhysicalMediaRepository() {
        val physicalMedia = mediaModule.domainObjects.namedElement("PhysicalMedia") as Entity;
        val repository = physicalMedia.repository;
        assertFalse(repository.isGapClass);
    }

    @Test
    def void assertPersonRepository() {
        val person = personModule.domainObjects.namedElement("Person") as Entity;
        val repository = person.repository;
        assertFalse(repository.isGapClass);
    }

    @Test
    def void assertPersonService() {
        val personService = personModule.services.namedElement("PersonService") as Service;
        val op = personService.operations.namedElement("findPaged") as ServiceOperation;
        assertNull(op.collectionType)
        assertEquals("PagedResult", op.type);
        assertEquals("Person", op.domainObjectType.name);
        assertEquals(
                "org.sculptor.framework.domain.PagedResult<org.fornax.cartridges.sculptor.examples.library.person.domain.Person>",
                op.typeName);
    }


}